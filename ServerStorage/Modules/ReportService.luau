--!strict
local players = game:GetService('Players')
local httpServ = game:GetService('HttpService')
local txServ = game:GetService('TextService')
local rep = game:GetService('ReplicatedStorage')

local Config = require(game:GetService('ServerStorage').Modules.ReportConfig)
local gameConfig = require(rep.Modules.Configs.GameConfig)
local ReportPackets = require(rep.Modules.Packets.ReportPackets).packets
local Promise = require(rep.Modules.Imported.Backend.Promise)
local Scythe = require(rep.Modules.Imported.Utility.Scythe)

local ReportService = {}
ReportService.__slittttName = 'ReportService'
ReportService.Dependencies = {'DataManager'}

local allowedDevices = {PC = true, Mobile = true, Console = true, VR = true}

type Field = {name: string, value: string, inline: boolean}

type Result = {ok: boolean, reason: string?, remaining: number?, cooldown: number?}

type ReportPromise = Promise.Promise

type Submission = {sending: boolean?, delivered: boolean?, promise: ReportPromise?}

type Service = typeof(ReportService) & {
	Get: (unknown, string) -> unknown,
	_data: typeof(require(script.Parent.DataManager)),
	_scope: number,
	_lastSubmit: {[Player]: number},
	_inFlight: {[Player]: Submission},
	_active: boolean,
}

local function fromHex(text: unknown): string?
	if typeof(text) ~= 'string' or #text % 2 ~= 0 or text:match('[^0-9a-fA-F]') then
		return nil
	end

	return (text:gsub('%x%x', function(pair)
		return string.char(tonumber(pair, 16) :: number)
	end))
end

local function filterText(text: string, authorUserId: number): string?
	local s
	local result

	s, result = pcall(function()
		local filtered = txServ:FilterStringAsync(text, authorUserId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)

	if s and type(result) == 'string' and #result > 0 then
		return result
	end

	warn(`[ReportService] Text filtering failed for user {authorUserId}`)
	return nil
end

local function sanitizeForDiscord(text: string): string
	text = text:gsub('`', "'")
	text = text:gsub('@', '@\226\128\139')
	return text
end

function ReportService.ContextFields(self: Service, player: Player): {Field}
	local playtime = self._data:GetStat(player, 'playtime')
	local session = self._data:GetSessionStart(player)

	if session then
		playtime += os.time() - session
	end

	return {
		{name = 'Cash', value = tostring(self._data:GetStat(player, 'cash')), inline = true},
		{name = 'Playtime (seconds)', value = tostring(math.floor(playtime)), inline = true},
		{name = 'Joins', value = tostring(self._data:GetStat(player, 'timesJoined')), inline = true},
		{name = 'Place', value = tostring(game.PlaceId), inline = true},
		{name = 'Server', value = if game.JobId == '' then 'Studio' else game.JobId, inline = false},
	}
end

local function sendWebhook(player: Player, device: string, message: string, context: {Field}): (boolean, boolean)
	local fields = {
		{name = 'Player', value = `{player.DisplayName} (@{player.Name})\n\`{player.UserId}\``, inline = true},
		{name = 'Device', value = device, inline = true},
		{name = 'Version', value = `v{game.PlaceVersion}`, inline = true},
	}

	for _, v in context do
		table.insert(fields, v)
	end

	table.insert(fields, {name = 'Message', value = message, inline = false})

	local payload = {
		username = 'Bug Reports',
		allowed_mentions = {parse = {}},
		embeds = {
			{
				title = 'Bug Report',
				color = 15844367,
				fields = fields,
				timestamp = DateTime.now():ToIsoDate(),
			},
		},
	}

	local body = httpServ:JSONEncode(payload)
	local s
	local response

	s, response = pcall(function()
		return httpServ:RequestAsync({
			Url = Config.webhookUrl,
			Method = 'POST',
			Headers = {['Content-Type'] = 'application/json'},
			Body = body,
			Timeout = Config.httpTimeout,
		})
	end)

	if not s then
		warn(`[ReportService] Webhook request failed for user {player.UserId}; delivery is unconfirmed`)
		return false, true
	end

	if not response.Success then
		warn(`[ReportService] Webhook returned HTTP {response.StatusCode} for user {player.UserId}`)
		return false, false
	end

	return true, false
end

function ReportService.Submit(self: Service, player: Player, encoded: string, device: string): Result
	if not self._active or player.Parent ~= players or Config.webhookUrl == '' or not httpServ.HttpEnabled then
		return {ok = false, reason = 'unavailable'}
	end

	local now = os.clock()
	local last = self._lastSubmit[player]

	if self._inFlight[player] then
		return {ok = false, reason = 'cooldown', remaining = Config.cooldown}
	end

	if last and now - last < Config.cooldown then
		return {ok = false, reason = 'cooldown', remaining = math.ceil(Config.cooldown - (now - last))}
	end

	if typeof(encoded) ~= 'string' then
		return {ok = false, reason = 'invalid'}
	end

	if #encoded > Config.maxLength * 8 then
		return {ok = false, reason = 'long'}
	end

	local message = fromHex(encoded)

	if not message then
		return {ok = false, reason = 'invalid'}
	end

	message = message:gsub('^%s*(.-)%s*$', '%1')

	local length = utf8.len(message)

	if not length then
		return {ok = false, reason = 'invalid'}
	end

	if length < Config.minLength then
		return {ok = false, reason = 'short'}
	end

	if length > Config.maxLength then
		return {ok = false, reason = 'long'}
	end

	if typeof(device) ~= 'string' or not allowedDevices[device] then
		device = 'Unknown'
	end

	local state: Submission = {}

	self._inFlight[player] = state
	self._lastSubmit[player] = now

	local work = Promise.try(function()
		local filtered = filterText(message, player.UserId)

		if not filtered then
			return {ok = false, reason = 'filter'}
		end

		local context = self:ContextFields(player)

		if not self._active or player.Parent ~= players then
			return {ok = false, reason = 'unavailable'}
		end

		state.sending = true

		local sent
		local uncertain

		sent, uncertain = sendWebhook(player, device, sanitizeForDiscord(filtered), context)
		state.sending = uncertain
		state.delivered = sent

		if not sent then
			return {ok = false, reason = 'send'}
		end

		return {ok = true, cooldown = Config.cooldown}
	end):timeout(Config.operationTimeout)

	state.promise = work:catch(function(err: unknown): Result
		if Promise.Error.isKind(err, Promise.Error.Kind.TimedOut) then
			warn(`[ReportService] Submission timed out for user {player.UserId}`)
			return {ok = false, reason = 'timeout'}
		end

		task.spawn(error, `[ReportService] Submission failed for user {player.UserId}:\n{err}`, 0)
		return {ok = false, reason = 'internal'}
	end):finally(function()
		if self._inFlight[player] == state then
			self._inFlight[player] = nil

			if not state.delivered and not state.sending then
				self._lastSubmit[player] = os.clock() - Config.cooldown + Config.failurePenalty
			end
		end
	end)

	Scythe.addPromise(self._scope, state.promise)

	local s
	local result

	s, result = (state.promise :: ReportPromise):await()

	return if s then result else {ok = false, reason = 'cancelled'}
end

function ReportService.Init(self: Service)
	if not gameConfig.features.bugReports then
		return
	end

	self._data = self:Get('DataManager') :: typeof(require(script.Parent.DataManager))
	self._scope = Scythe.scope()
	self._lastSubmit = {} :: {[Player]: number}
	self._inFlight = {} :: {[Player]: Submission}
	self._active = true

	if Config.webhookUrl == '' or not httpServ.HttpEnabled then
		warn('[ReportService] Reports unavailable: configure ReportConfig.webhookUrl and enable HTTP requests')
	end

	Scythe.add(self._scope, ReportPackets.Submit.listen(function(request, player)
		player = player :: Player

		if #request.requestId == 0 or #request.requestId > 64 then
			return
		end

		local result = self:Submit(player, request.encoded, request.device)

		if self._active and player.Parent == players and result.reason ~= 'cancelled' then
			ReportPackets.Result.sendTo({
				requestId = request.requestId,
				ok = result.ok,
				reason = result.reason or '',
				remaining = result.remaining or 0,
				cooldown = result.cooldown or 0,
			}, player)
		end
	end))

	Scythe.connect(self._scope, players.PlayerRemoving, function(player)
		local state = self._inFlight[player]

		self._inFlight[player] = nil
		self._lastSubmit[player] = nil

		if state then
			(state.promise :: ReportPromise):cancel()
		end
	end)
end

function ReportService.Destroy(self: Service)
	if not self._active then
		return
	end

	self._active = false

	Scythe.destroy(self._scope)
	table.clear(self._inFlight)
	table.clear(self._lastSubmit)
end

return ReportService