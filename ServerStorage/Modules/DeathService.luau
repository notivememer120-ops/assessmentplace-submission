--!strict
local rep = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local debris = game:GetService("Debris")

local config = require(rep.Modules.Configs.DeathUIConfig)
local rules = require(rep.Modules.Configs.GameConfig).death
local RespawnPackets = require(rep.Modules.Packets.RespawnPackets).packets
local RagdollRig = require(rep.Modules.Gameplay.RagdollRig)
local RagdollService = require(rep.Modules.Imported.Backend.RagdollService)
local Scythe = require(rep.Modules.Imported.Utility.Scythe)

type State = {
	scope: number,
	character: number,
	dead: boolean,
	char: Model?,
}

local DeathService = {}
DeathService.__slittttName = "DeathService"

type Service = typeof(DeathService) & {
	_states: {[Player]: State},
	_scope: number,
}

function DeathService._onDeath(self: Service, player: Player, char: Model, hum: Humanoid)
	local state = self._states[player]

	if not state or state.char ~= char or state.dead then
		return
	end

	state.dead = true

	player:SetAttribute(config.causeAttribute, hum:GetAttribute(config.causeAttribute))
	player:SetAttribute(config.deadAttribute, true)
	debris:AddItem(char, rules.ragdollLifetime)

	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false

	RagdollRig.convert(char)

	local parts = {}

	for _, v in char:GetDescendants() do
		if v:IsA("BasePart") then
			v.Anchored = false
			v.CanTouch = false
			v.CanQuery = false
			v.CanCollide = v.Name ~= "HumanoidRootPart" and not v:FindFirstAncestorOfClass("Accessory") and not v:FindFirstAncestorOfClass("Tool")
			v.CollisionGroup = "Player"

			table.insert(parts, v)
		end
	end

	for _, v in parts do
		v:SetNetworkOwner(nil)
	end

	assert(RagdollService.Ragdoll(char), `Could not ragdoll {char:GetFullName()}`)
end

function DeathService._bindCharacter(self: Service, player: Player, state: State, char: Model)
	Scythe.clean(state.character)

	state.char = char
	state.dead = false

	player:SetAttribute(config.deadAttribute, false)
	player:SetAttribute(config.causeAttribute, nil)

	Scythe.connect(state.character, char.Destroying, function()
		if player.Character == char then
			player.Character = nil
		end
	end)

	Scythe.add(state.character, task.defer(function()
		local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?

		if state.char ~= char then
			return
		end

		assert(hum, `No Humanoid in {char:GetFullName()} after 10s`)

		hum.BreakJointsOnDeath = false

		Scythe.connect(state.character, hum.Died, function()
			self:_onDeath(player, char, hum)
		end)
		Scythe.connect(state.character, hum.HealthChanged, function(health)
			if health <= 0 then
				self:_onDeath(player, char, hum)
			end
		end)

		if hum.Health <= 0 then
			self:_onDeath(player, char, hum)
		end
	end))
end

function DeathService.Kill(self: Service, hum: Humanoid, cause: string): boolean
	if hum.Health <= 0 then
		return false
	end

	hum:SetAttribute(config.causeAttribute, cause)
	hum.BreakJointsOnDeath = false
	hum.Health = 0

	local player = players:GetPlayerFromCharacter(hum.Parent :: Model)

	if player then
		self:_onDeath(player, hum.Parent :: Model, hum)
	end

	return true
end

function DeathService.Init(self: Service)
	self._scope = Scythe.scope()
	self._states = {} :: {[Player]: State}

	Scythe.add(self._scope, RespawnPackets.Reset.listen(function(_, player)
		player = player :: Player

		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")

		if hum then
			self:Kill(hum, "reset")
		end
	end))
end

function DeathService.OnPlayerJoined(self: Service, player: Player)
	local scope = Scythe.scope()
	local state: State = {scope = scope, dead = false, character = Scythe.extend(scope)}

	self._states[player] = state

	player:SetAttribute(config.deadAttribute, false)

	Scythe.connect(state.scope, player.CharacterAdded, function(char)
		self:_bindCharacter(player, state, char)
	end)
	Scythe.connect(state.scope, player.CharacterRemoving, function(char)
		if state.char == char then
			state.char = nil

			Scythe.clean(state.character)
		end
	end)

	if player.Character then
		self:_bindCharacter(player, state, player.Character)
	end
end

function DeathService.OnPlayerRemoving(self: Service, player: Player)
	local state = self._states[player]

	if not state then
		return
	end

	self._states[player] = nil

	Scythe.destroy(state.scope)
end

function DeathService.Destroy(self: Service)
	Scythe.destroy(self._scope)

	for player in self._states do
		self:OnPlayerRemoving(player)
	end
end

return DeathService :: Service