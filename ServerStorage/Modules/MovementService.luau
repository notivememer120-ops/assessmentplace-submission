--!strict
local rep = game:GetService("ReplicatedStorage")
local runServ = game:GetService("RunService")

local GameConfig = require(rep.Modules.Configs.GameConfig)
local MovementPackets = require(rep.Modules.Packets.MovementPackets)
local RateGate = require(rep.Modules.Gameplay.RateGate)
local Scythe = require(rep.Modules.Imported.Utility.Scythe)

local SprintIntent = MovementPackets.packets.SprintIntent

local speeds = GameConfig.movement
local rules = GameConfig.stamina

local intentGate = RateGate.new(0.1)
local movingSpeedMin = 1
local staminaStep = 0.02
local flatMask = Vector3.new(1, 0, 1)

type State = {
	stamina: number,
	sprinting: boolean,
	locked: boolean,
	stoppedAt: number,
	character: number,
	lifetime: number,
	hum: Humanoid?,
	lastPos: Vector3?,
}

local states: {[Player]: State} = {}

local MovementService = {}
MovementService.__slittttName = "MovementService"

local function speedFor(st: State): number
	return if st.sprinting then speeds.runSpeed else speeds.walkSpeed
end

local function stopSprint(st: State)
	if not st.sprinting then
		return
	end

	st.sprinting = false
	st.stoppedAt = os.clock()
end

local function setIfChanged(player: Player, name: string, value: boolean)
	if player:GetAttribute(name) ~= value then
		player:SetAttribute(name, value)
	end
end

local function mirror(player: Player, st: State)
	local shown = player:GetAttribute("stamina") :: number
	local edge = st.stamina == 0 or st.stamina == 1

	if math.abs(st.stamina - shown) >= staminaStep or (edge and shown ~= st.stamina) then
		player:SetAttribute("stamina", st.stamina)
	end

	setIfChanged(player, "sprinting", st.sprinting)
	setIfChanged(player, "sprintLocked", st.locked)
end

local function onCharacterAdded(player: Player, st: State, char: Model)
	Scythe.clean(st.character)

	st.hum = nil
	st.lastPos = nil
	st.sprinting = false
	st.locked = false
	st.stamina = 1
	st.stoppedAt = os.clock()

	Scythe.add(st.character, task.defer(function()
		local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?

		if player.Character ~= char then
			return
		end

		assert(hum, `no Humanoid in {char:GetFullName()} after 5s`)

		hum.WalkSpeed = speedFor(st)
		st.hum = hum

		Scythe.connect(st.character, hum.Died, function()
			stopSprint(st)
		end)
	end))
end

local function step(dt: number)
	local now = os.clock()

	for player, st in states do
		local hum = st.hum

		if not hum or hum.Parent == nil or hum.Health <= 0 then
			continue
		end

		local root = hum.RootPart

		if not root then
			continue
		end

		local pos = root.Position
		local moving = false

		if st.lastPos then
			moving = ((pos - st.lastPos) * flatMask).Magnitude / dt > movingSpeedMin
		end

		st.lastPos = pos

		if st.sprinting then
			if moving then
				st.stamina = math.max(0, st.stamina - dt / rules.fullRunSeconds)
			end

			if st.stamina <= 0 then
				st.locked = true

				stopSprint(st)
			end
		elseif st.stamina < 1 and now - st.stoppedAt >= rules.regenDelaySeconds then
			st.stamina = math.min(1, st.stamina + dt / rules.fullRegenSeconds)

			if st.locked and st.stamina >= rules.resumeThreshold then
				st.locked = false
			end
		end

		local speed = speedFor(st)

		if hum.WalkSpeed ~= speed then
			hum.WalkSpeed = speed
		end

		mirror(player, st)
	end
end

function MovementService:Init()
	SprintIntent.listen(function(data, player)
		player = player :: Player

		local st = states[player]

		if not st then
			return
		end

		if not data.running then
			stopSprint(st)
			return
		end

		if st.sprinting or intentGate:tooFast(player) then
			return
		end

		if st.locked or st.stamina <= 0 then
			return
		end

		local hum = st.hum

		if not hum or hum.Parent == nil or hum.Health <= 0 then
			return
		end

		st.sprinting = true
	end)

	runServ.Heartbeat:Connect(step)
end

function MovementService:OnPlayerJoined(player: Player)
	local st: State = {
		stamina = 1,
		sprinting = false,
		locked = false,
		stoppedAt = os.clock(),
		character = Scythe.scope(),
		lifetime = Scythe.scope(),
	}

	states[player] = st

	player:SetAttribute("stamina", 1)
	player:SetAttribute("sprinting", false)
	player:SetAttribute("sprintLocked", false)

	Scythe.connect(st.lifetime, player.CharacterAdded, function(char)
		onCharacterAdded(player, st, char)
	end)

	if player.Character then
		onCharacterAdded(player, st, player.Character)
	end
end

function MovementService:OnPlayerRemoving(player: Player)
	local st = states[player]

	if not st then
		return
	end

	Scythe.destroy(st.character)
	Scythe.destroy(st.lifetime)

	intentGate:forget(player)

	states[player] = nil
end

return MovementService