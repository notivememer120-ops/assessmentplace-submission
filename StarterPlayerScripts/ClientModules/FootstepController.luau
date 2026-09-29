local players = game:GetService("Players")
local rep = game:GetService("ReplicatedStorage")
local soundServ = game:GetService("SoundService")
local content = game:GetService("ContentProvider")
local runServ = game:GetService("RunService")

local config = require(rep.Modules.Configs.FootstepConfig)
local WaitFor = require(rep.Modules.Gameplay.WaitFor)
local Observers = require(rep.Modules.Imported.Backend.Observers)
local Promise = require(rep.Modules.Imported.Backend.Promise)
local Scythe = require(rep.Modules.Imported.Utility.Scythe)

local player = players.LocalPlayer
local random = Random.new()
local FootstepController = {}
FootstepController.__slittttName = "FootstepController"
FootstepController.Dependencies = {"SettingsTopbar"}

function FootstepController:_mute(inst, scope)
	if inst.Name ~= "Running" or not (inst:IsA("Sound") or inst:IsA("AudioPlayer")) then
		return
	end

	local volume = inst.Volume
	inst.Volume = 0

	local connection = inst:GetPropertyChangedSignal("Volume"):Connect(function()
		if inst.Volume ~= 0 then
			inst.Volume = 0
		end
	end)

	Scythe.add(scope, function()
		connection:Disconnect()

		inst.Volume = volume
	end)
end

function FootstepController:_play(state, material)
	if material == Enum.Material.Air or material == Enum.Material.Water then
		return
	end

	local bank = config.materials[material]

	if not bank then
		bank = config.fallback
	end

	local clips = config.banks[bank]
	local index

	if #clips > 1 and state.bank == bank then
		index = random:NextInteger(1, #clips - 1)

		if index >= state.index then
			index += 1
		end
	else
		index = random:NextInteger(1, #clips)
	end

	state.bank = bank
	state.index = index

	local clip = clips[index]
	local pool = state.clips[clip.id]
	pool.voice = pool.voice % #pool.sounds + 1

	local volume = clip.volume

	if config.volumeOffsets[material] then
		volume += config.volumeOffsets[material]
	end

	local pitch = config.pitchRange

	if #clips == 1 then
		pitch = config.singleClipPitchRange
	end

	local sound = pool.sounds[pool.voice]
	sound:Stop()
	sound.PlaybackSpeed = random:NextNumber(pitch.Min, pitch.Max)
	sound.Volume = math.clamp(volume * random:NextNumber(config.volumeRange.Min, config.volumeRange.Max), 0, 10)
	sound:Play()
end

function FootstepController:_step(state, now, dt)
	local wasMoving = state.moving
	state.moving = false

	local hum = state.hum
	local root = state.root

	if state.player.Character ~= state.char or not root:IsDescendantOf(workspace) or hum.Health <= 0 or hum.Sit or hum.PlatformStand then
		return
	end

	local current = hum:GetState()

	if current ~= Enum.HumanoidStateType.Running and current ~= Enum.HumanoidStateType.Landed then
		return
	end

	if state.player == player and hum.MoveDirection.Magnitude == 0 then
		return
	end

	local camera = workspace.CurrentCamera

	if not camera or (camera.CFrame.Position - root.Position).Magnitude > config.rollOffMaxDistance then
		return
	end

	local height = root.Size.Y / 2 + hum.HipHeight

	if state.leg then
		height += state.leg.Size.Y
	end

	state.params.CollisionGroup = root.CollisionGroup

	local hit = workspace:Raycast(root.Position, Vector3.new(0, -height - config.groundTolerance, 0), state.params)

	if not hit then
		return
	end

	local velocity = root.AssemblyLinearVelocity

	if hit.Instance:IsA("BasePart") then
		velocity -= hit.Instance:GetVelocityAtPosition(root.Position)
	end

	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

	if speed < config.minimumSpeed then
		return
	end

	state.moving = true

	local stride = config.baseStepInterval * config.baseSpeed

	if wasMoving then
		state.distance += speed * math.min(dt, config.maximumDelta)
	else
		state.distance = stride
	end

	if state.distance < stride or now - state.lastStep < config.minimumInterval then
		return
	end

	state.distance %= stride
	state.lastStep = now

	self:_play(state, hit.Material)
end

function FootstepController:_bindRoot(plr, char, hum, root)
	local scope = Scythe.scope()

	Scythe.add(scope, task.defer(function()
		local state = {player = plr, char = char, hum = hum, root = root, distance = 0, moving = false, lastStep = -math.huge, sounds = {}, clips = {}}

		if hum.RigType == Enum.HumanoidRigType.R6 then
			state.leg = WaitFor:get(char, "Left Leg", 10)
		end

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {workspace.Players, char}
		params.RespectCanCollide = true
		state.params = params

		for _, bank in config.banks do
			local voices = config.voicesPerClip

			if #bank == 1 then
				voices = config.singleClipVoices
			end

			for _, clip in bank do
				if state.clips[clip.id] then
					continue
				end

				local pool = {voice = 0, sounds = {}}

				state.clips[clip.id] = pool

				for i = 1, voices do
					local sound = Scythe.add(scope, Instance.new("Sound"))
					sound.Name = `Footstep{#state.sounds + 1}`
					sound.SoundId = clip.id
					sound.RollOffMinDistance = config.rollOffMinDistance
					sound.RollOffMaxDistance = config.rollOffMaxDistance
					sound.RollOffMode = Enum.RollOffMode.InverseTapered
					sound.SoundGroup = self._soundGroup
					sound.Parent = root

					table.insert(pool.sounds, sound)
					table.insert(state.sounds, sound)
				end
			end
		end

		content:PreloadAsync(state.sounds)

		for _, sound in state.sounds do
			assert(sound.IsLoaded, `Footstep audio failed to load: {sound.SoundId}`)
		end

		Scythe.connect(scope, root.ChildAdded, function(inst)
			self:_mute(inst, scope)
		end)

		for _, v in root:GetChildren() do
			self:_mute(v, scope)
		end

		self._characters[char] = state

		Scythe.add(scope, function()
			if self._characters[char] == state then
				self._characters[char] = nil
			end
		end)
	end))

	return function()
		Scythe.destroy(scope)
	end
end

function FootstepController:_bindCharacter(plr, char)
	local scope = Scythe.scope()

	Scythe.add(scope, task.defer(function()
		local hum = WaitFor:get(char, "Humanoid", 10)

		Scythe.add(scope, Observers.observeProperty(hum, "RootPart", function(root)
			if not root then
				return
			end

			return self:_bindRoot(plr, char, hum, root)
		end))
	end))

	return function()
		Scythe.destroy(scope)
	end
end

function FootstepController:_bindPlayer(plr)
	return Observers.observeProperty(plr, "Character", function(char)
		if not char then
			return
		end

		return Observers.observeProperty(char, "Parent", function(parent)
			if not parent then
				return
			end

			return self:_bindCharacter(plr, char)
		end)
	end)
end

function FootstepController:Init()
	self._scope = Scythe.scope()
	self._characters = {}

	if not config.enabled then
		warn("[Footsteps] Custom footsteps are disabled pending audio IDs in FootstepConfig")
		return
	end

	for k, v in config.banks do
		assert(#v > 0, `FootstepConfig.banks.{k} has no clips`)

		for _, clip in v do
			assert(clip.id ~= "", `FootstepConfig.banks.{k} has an empty audio ID`)
		end
	end

	self._soundGroup = WaitFor:get(soundServ, "SFXGroup")

	local preload = Scythe.extend(self._scope)
	local sounds = {}
	local ids = {}

	for _, bank in config.banks do
		for _, clip in bank do
			if ids[clip.id] then
				continue
			end

			ids[clip.id] = true

			local sound = Scythe.add(preload, Instance.new("Sound"))
			sound.SoundId = clip.id
			sound.Parent = script

			table.insert(sounds, sound)
		end
	end

	return Scythe.addPromise(self._scope, Promise.try(function()
		content:PreloadAsync(sounds)

		for _, sound in sounds do
			assert(sound.IsLoaded, `Footstep audio failed to preload: {sound.SoundId}`)
		end
	end):timeout(config.preloadTimeout):andThen(function()
		Scythe.destroy(preload)
		Scythe.add(self._scope, Observers.observePlayer(function(plr)
			return self:_bindPlayer(plr)
		end))
		Scythe.connect(self._scope, runServ.Heartbeat, function(dt)
			local now = os.clock()

			for _, v in self._characters do
				if self._soundGroup.Volume == 0 then
					v.moving = false
				else
					self:_step(v, now, dt)
				end
			end
		end)
	end))
end

function FootstepController:Destroy()
	Scythe.destroy(self._scope)
	table.clear(self._characters)
end

return FootstepController