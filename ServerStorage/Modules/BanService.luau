--!strict
local DataStoreService = game:GetService("DataStoreService")
local msgServ = game:GetService("MessagingService")
local players = game:GetService("Players")
local rep = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DataStoreKeys = require(ServerStorage.Modules.DataStoreKeys)
local Signal = require(rep.Modules.Imported.Utility.Signal)
local store = DataStoreService:GetDataStore(DataStoreKeys.BanList)

local BanService = {}
BanService.__slittttName = "BanService"
BanService.PlayerBanned = Signal()

local bkey = "bans"
local banTopic = "BanSync"
local cache: {[string]: string} = {}
local loaded = false

local function keyOf(userId: number): string
	return tostring(userId)
end

local function pull()
	local attempt = 0

	while true do
		attempt += 1

		local s, data = pcall(function()
			return store:GetAsync(bkey)
		end)

		if s then
			cache = typeof(data) == "table" and data or {}
			loaded = true
			return
		end

		warn(`ban list fetch failed (attempt {attempt}): {data}`)
		task.wait(math.min(2 ^ attempt, 30))
	end
end

local function pushEntry(userId: number, reason: string?)
	task.spawn(function()
		local s, err = pcall(function()
			store:UpdateAsync(bkey, function(data: unknown)
				if typeof(data) ~= "table" then
					data = {}
				end

				(data :: {[string]: string})[keyOf(userId)] = reason
				
				return data
			end)
		end)
		
		if not s then
			warn(`ban list save failed: {err}`)
		end
	end)
end

-- fire-and-forget: every live server applies it if it cares (has the player / trusts the
-- cache); the datastore stays the source of truth for servers that boot later
local function broadcast(userId: number, reason: string?)
	task.spawn(function()
		local s, err = pcall(function()
			msgServ:PublishAsync(banTopic, {userId = userId, reason = reason})
		end)

		if not s then
			warn(`ban broadcast failed for uid={userId}: {err}`)
		end
	end)
end

local function applyEntry(userId: number, reason: string?)
	cache[keyOf(userId)] = reason

	if not reason then
		return
	end

	local plr = players:GetPlayerByUserId(userId :: any)

	if plr then
		plr:Kick(reason)
	end
end

function BanService:Ban(userId: number, reason: string?)
	reason = reason or "banned by admin"

	applyEntry(userId, reason)
	pushEntry(userId, reason)
	broadcast(userId, reason)

	BanService.PlayerBanned:Fire(userId)
end

function BanService:Unban(userId: number)
	cache[keyOf(userId)] = nil

	pushEntry(userId, nil)
	broadcast(userId, nil)
end

function BanService:List()
	local out = {}

	for uid, reason in cache do
		table.insert(out, {userId = tonumber(uid) or uid, reason = reason})
	end

	return out
end

function BanService:CheckAndKick(player: Player): boolean
	if not loaded then
		local t = 0
		
		while not loaded and t < 30 do
			task.wait(0.1)

			t += 0.1
		end

		if not loaded then
			warn(`ban list still not loaded after 30s, admitting {player.Name} unchecked`)
		end
	end

	local reason = cache[keyOf(player.UserId)]

	if reason then
		player:Kick(reason)
		return true
	end

	return false
end

function BanService:Init()
	task.spawn(pull)

	task.spawn(function()
		local s, err = pcall(function()
			msgServ:SubscribeAsync(banTopic, function(msg)
				local d = msg.Data

				if typeof(d) ~= "table" or not d.userId then
					return
				end

				-- publishers receive their own message; cache already matching = nothing to do
				if cache[keyOf(d.userId)] == d.reason then
					return
				end

				applyEntry(d.userId, d.reason)

				if d.reason then
					BanService.PlayerBanned:Fire(d.userId)
				end
			end)
		end)

		if not s then
			warn(`ban sync subscribe failed, cross-server bans off for this server: {err}`)
		end
	end)
end

return BanService