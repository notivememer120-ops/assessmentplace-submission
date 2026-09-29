--!strict
local players = game:GetService("Players")
local rep = game:GetService("ReplicatedStorage")

local RespawnPackets = require(rep.Modules.Packets.RespawnPackets).packets
local RateGate = require(rep.Modules.Gameplay.RateGate)
local Scythe = require(rep.Modules.Imported.Utility.Scythe)

local RespawnService = {}
RespawnService.__slittttName = "RespawnService"
RespawnService.Dependencies = {"DeathService"}

function RespawnService:_spawn(player: Player): boolean?
	if self._loading[player] or not self._joined[player] then
		return nil
	end

	self._loading[player] = true
	player.RespawnLocation = self._spawnPoint
	player:SetAttribute("Respawning", true)
	player:SetAttribute("RespawnFailed", false)

	local s
	local err

	s, err = pcall(player.LoadCharacterAsync, player)
	self._loading[player] = nil

	if player.Parent ~= players or not self._joined[player] then
		return nil
	end

	player:SetAttribute("Respawning", false)
	player:SetAttribute("RespawnFailed", not s)

	if not s then
		error(`Respawn failed for {player.Name}: {tostring(err)}`, 0)
	end

	return true
end

function RespawnService:Request(player: Player)
	if not self._joined[player] or self._loading[player] then
		return
	end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")

	if char and char.Parent and (not hum or hum.Health > 0) then
		return
	end

	if self._gate:tooFast(player) then
		return
	end

	self:_spawn(player)
end

function RespawnService:Init()
	players.CharacterAutoLoads = false
	self._spawnPoint = workspace.Lobby.SpawnLocation
	self._joined = {} :: {[Player]: boolean}
	self._loading = {} :: {[Player]: boolean}
	self._gate = RateGate.new(0.5)
	self._scope = Scythe.scope()

	Scythe.add(self._scope, RespawnPackets.Request.listen(function(_, player)
		self:Request(player :: Player)
	end))
end

function RespawnService:OnPlayerJoined(player: Player)
	self._joined[player] = true

	if not player.Character then
		self:_spawn(player)
	end
end

function RespawnService:OnPlayerRemoving(player: Player)
	self._joined[player] = nil
	self._loading[player] = nil

	self._gate:forget(player)
end

function RespawnService:Destroy()
	Scythe.destroy(self._scope)
	table.clear(self._joined)
end

return RespawnService