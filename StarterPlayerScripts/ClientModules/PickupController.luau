--!strict
local rep = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local runServ = game:GetService("RunService")
local sounds = game:GetService("SoundService")
local guiServ = game:GetService("GuiService")

local config = require(rep.Modules.Configs.PickupConfig)
local packets = require(rep.Modules.Packets.PickupPackets).packets
local collectQuery = require(rep.Modules.Packets.PickupPackets).queries.Collect
local Motion = require(rep.Modules.Gameplay.PickupMotion)
local TagBinder = require(rep.Modules.Gameplay.TagBinder)
local WaitFor = require(rep.Modules.Gameplay.WaitFor)
local CoinText = require(rep.Modules.Gameplay.CoinText)
local Scythe = require(rep.Modules.Imported.Utility.Scythe)
local Promise = require(rep.Modules.Imported.Backend.Promise)
local Timer = require(rep.Modules.Imported.Backend.Timer)

local player = players.LocalPlayer :: Player
local PickupController = {}
PickupController.__slittttName = "PickupController"
PickupController.Dependencies = {"SettingsTopbar"}

type Coin = {
	model: Model,
	part: BasePart,
	origin: CFrame,
	phase: number,
	claimed: boolean?,
}

type CoinModel = typeof(rep.Assets.PickupEffects.Coin) & {PrimaryPart: typeof(rep.Assets.PickupEffects.Coin.Handle)}

type Flight = {
	scope: Scythe.Scope,
	model: CoinModel,
	trail: Trail,
	origin: CFrame,
	root: BasePart,
	char: Model,
	claimer: Player,
	at: number,
	elapsed: number,
	arrived: boolean?,
	label: typeof(rep.Assets.PickupEffects.Label)?,
	labelOrigin: Vector3?,
}

type Collection = {
	id: number,
	playerId: number,
	character: Instance,
	position: Vector3,
	amount: number,
	at: number,
}

type Controller = typeof(PickupController) & {
	_scope: Scythe.Scope,
	_coins: {[number]: Coin},
	_flights: {[number]: Flight},
	_seen: {[number]: number},
	_pitch: number,
	_lastSound: number,
	_pending: boolean,
	_sound: Sound,
	_templates: typeof(rep.Assets.PickupEffects),
	_folder: Folder,
	_pickups: Instance,
}

function PickupController._bind(self: Controller, model: Model, scope: Scythe.Scope)
	Scythe.add(scope, task.defer(function()
		local id = model:GetAttribute("PickupId") :: number
		local part = WaitFor:get(model, "Handle") :: BasePart

		if part.Parent ~= model or model.Parent ~= self._pickups then return end

		local transparency = part.LocalTransparencyModifier
		local entry: Coin = {model = model, part = part, origin = model:GetAttribute("PickupOrigin") :: CFrame, phase = model:GetAttribute("PickupPhase") :: number}

		self._coins[id] = entry

		local function changed()
			entry.claimed = (model:GetAttribute("Claimed") :: boolean?) or self._seen[id] ~= nil
			part.LocalTransparencyModifier = if entry.claimed then 1 else transparency
		end

		Scythe.connect(scope, model:GetAttributeChangedSignal("Claimed"), changed)
		Scythe.add(scope, function()
			if self._coins[id] == entry then self._coins[id] = nil end

			if model:IsDescendantOf(workspace) then
				part.LocalTransparencyModifier = transparency

				model:PivotTo(entry.origin)
			end
		end)

		changed()
	end))
end

function PickupController._chime(self: Controller)
	local now = os.clock()

	self._pitch = if now - self._lastSound > config.sound.resetSeconds then 1 else math.min(self._pitch * (1 + config.sound.pitchStep), config.sound.pitchCap)
	self._lastSound = now

	local scope = Scythe.extend(self._scope)
	local sound = Scythe.clone(scope, self._sound)
	sound.PlaybackSpeed = self._pitch
	sound.Parent = sounds.SFX

	local function finish()
		if Scythe.isAlive(scope) then Scythe.discard(self._scope, scope) end
	end

	Scythe.once(scope, sound.Ended, finish)
	Scythe.add(scope, task.delay(config.sound.lifetime, finish))

	sound:Play()
end

function PickupController._collected(self: Controller, data: Collection)
	local now = workspace:GetServerTimeNow()

	for id, untilAt in self._seen do
		if now >= untilAt then self._seen[id] = nil end
	end

	if self._seen[data.id] or now - data.at > config.packetLifetime then return end

	self._seen[data.id] = now + config.packetLifetime

	local entry: Coin? = self._coins[data.id]

	if entry and (entry.part.Parent ~= entry.model or entry.model.Parent ~= self._pickups) then entry = nil end

	local origin = if entry then entry.model:GetPivot() else CFrame.new(data.position)

	if entry then
		entry.claimed = true
		entry.part.LocalTransparencyModifier = 1
	end

	local claimer = players:GetPlayerByUserId(data.playerId :: any)
	local char = data.character :: Model

	if not claimer or not char or claimer.Character ~= char then return end

	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?

	if not root or not root:IsDescendantOf(workspace) or not entry and claimer ~= player then return end

	local scope = Scythe.extend(self._scope)
	local model = Scythe.clone(scope, self._templates.Coin) :: CoinModel

	model:PivotTo(origin)
	model.Parent = self._folder

	local flight: Flight = {scope = scope, model = model, trail = model.PrimaryPart.Trail, origin = origin, root = root, char = char, claimer = claimer, at = os.clock(), elapsed = 0}
	flight.trail.Enabled = not guiServ.ReducedMotionEnabled

	if claimer == player then
		local label = Scythe.clone(scope, self._templates.Label)
		local text = `+{CoinText(data.amount)} to bag`

		label.BillboardGui.Shadow.Text = text
		label.BillboardGui.TheShadow.Text = text
		flight.labelOrigin = root.Position
		label.Position = flight.labelOrigin :: Vector3
		label.Parent = self._folder
		flight.label = label
	end

	self._flights[data.id] = flight

	Scythe.add(scope, task.delay(config.flight.duration, function()
		if flight.claimer.Character == flight.char and flight.root:IsDescendantOf(workspace) then self:_arrive(flight) end
	end))

	Scythe.add(scope, task.delay(math.max(config.flight.duration + config.flight.trailSeconds, config.label.seconds), function()
		self._flights[data.id] = nil

		Scythe.discard(self._scope, scope)
	end))
end

function PickupController._arrive(self: Controller, flight: Flight)
	if flight.arrived then return end

	flight.arrived = true
	flight.model:PivotTo(CFrame.new(flight.root.Position + Vector3.yAxis * config.flight.lift) * flight.origin.Rotation)
	flight.model.PrimaryPart.Transparency = 1
	flight.trail.Enabled = false

	if flight.claimer == player then self:_chime() end
end

function PickupController._request(self: Controller)
	if self._pending then return end

	local capacity = player:GetAttribute("BagCapacity") :: number?
	local count = player:GetAttribute("BagCount") :: number?

	if not capacity or count == nil or count >= capacity then return end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")

	if not hum or hum.Health <= 0 or not hum.RootPart then return end

	local nearest: number?
	local distance = config.range

	for id, v in self._coins do
		if v.claimed or v.model:GetAttribute("Zone") == 2 and not workspace:GetAttribute("Zone2Open") then continue end

		local delta = (hum.RootPart.Position - v.origin.Position).Magnitude

		if delta <= distance then
			nearest = id
			distance = delta
		end
	end

	if not nearest then return end

	local id = nearest

	self._pending = true

	Scythe.addPromise(self._scope, Promise.try(function()
		return collectQuery.invoke(id)
	end):andThen(function()
		self._pending = false
	end):catch(function(err)
		self._pending = false

		task.spawn(error, err)
	end))
end

function PickupController._step(self: Controller)
	local now = workspace:GetServerTimeNow()
	local reduced = guiServ.ReducedMotionEnabled
	local clock = os.clock()

	for _, entry in self._coins do
		if not entry.claimed and entry.part.Parent == entry.model and entry.model.Parent == self._pickups then
			entry.model:PivotTo(if reduced then entry.origin else Motion.hover(entry.origin, now, entry.phase, config.hover))
		end
	end

	for id, flight in self._flights do
		flight.elapsed = clock - flight.at

		if flight.claimer.Character ~= flight.char or not flight.root:IsDescendantOf(workspace) then
			Scythe.discard(self._scope, flight.scope)

			self._flights[id] = nil
			continue
		end

		local t = math.min(flight.elapsed / config.flight.duration, 1)

		if not flight.arrived then
			local target = flight.root.Position + Vector3.yAxis * config.flight.lift
			local position = Motion.flight(flight.origin.Position, target, t, if reduced then 0 else config.flight.height)

			flight.model:PivotTo(CFrame.new(position) * flight.origin.Rotation)

			if t == 1 then self:_arrive(flight) end
		end

		if flight.label then
			local progress = math.min(flight.elapsed / config.label.seconds, 1)

			flight.label.Position = (flight.labelOrigin :: Vector3) + Vector3.yAxis * progress * (if reduced then 0.5 else config.label.rise)
			flight.label.BillboardGui.Shadow.TextTransparency = progress
			flight.label.BillboardGui.TheShadow.TextTransparency = progress
		end

	end
end

function PickupController.Init(self: Controller)
	self._scope = Scythe.scope()
	self._coins = {}
	self._flights = {}
	self._seen = {}
	self._pitch = 1
	self._lastSound = -math.huge
	self._pending = false
	self._sound = sounds.SFX.CoinPickup
	self._templates = rep.Assets.PickupEffects
	self._folder = Scythe.add(self._scope, Instance.new("Folder"))
	self._folder.Name = "CoinEffects"
	self._folder.Parent = workspace
	self._pickups = WaitFor:get(workspace, "Pickups")

	Scythe.add(self._scope, TagBinder.bind(config.tag, function(model, scope) self:_bind(model, scope) end, self._pickups))
	Scythe.add(self._scope, packets.Collected.listen(function(data) self:_collected(data) end))
	Scythe.connect(self._scope, runServ.PreRender, function() self:_step() end)

	local timer = Scythe.add(self._scope, Timer.new(config.interval))

	Scythe.connect(self._scope, timer.Tick, function() self:_request() end)

	timer:Start()
end

function PickupController.Destroy(self: Controller)
	Scythe.destroy(self._scope)
	table.clear(self._coins)
	table.clear(self._flights)
	table.clear(self._seen)
end

return PickupController