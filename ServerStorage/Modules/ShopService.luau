--!strict
local rep = game:GetService("ReplicatedStorage")

local config = require(rep.Modules.Configs.ShopConfig)
local queries = require(rep.Modules.Packets.ShopPackets).queries
local RateGate = require(rep.Modules.Gameplay.RateGate)
local Scythe = require(rep.Modules.Imported.Utility.Scythe)

local ShopService = {}
ShopService.__slittttName = "ShopService"
ShopService.Dependencies = {"DataManager"}

type Service = typeof(ShopService) & {
	Get: (unknown, string) -> unknown,
	_scope: number,
	_players: {[Player]: {id: number, key: string, result: string}},
	_gate: typeof(RateGate.new(0)),
	_data: typeof(require(script.Parent.DataManager)),
}

function ShopService.Buy(self: Service, player: Player, data: {id: number, key: string}): string
	local state = self._players[player]

	if not state then return "busy" end

	if not config.Get(data.key) then return "invalid" end

	if data.id <= state.id then
		return if data.id == state.id and data.key == state.key then state.result else "stale"
	end

	if self._gate:tooFast(player) then return "busy" end

	local result = self._data:BuyItem(player, data.key)

	state.id = data.id
	state.key = data.key
	state.result = result
	return result
end

function ShopService.Init(self: Service)
	self._scope = Scythe.scope()
	self._players = {} :: {[Player]: {id: number, key: string, result: string}}
	self._gate = RateGate.new(config.requestInterval)
	self._data = self:Get("DataManager") :: typeof(require(script.Parent.DataManager))

	Scythe.add(self._scope, queries.Buy.listen(function(data, player) return self:Buy(player :: Player, data) end))
end

function ShopService.OnPlayerJoined(self: Service, player: Player)
	self._players[player] = {id = 0, key = "", result = "busy"}
end

function ShopService.OnPlayerRemoving(self: Service, player: Player)
	self._players[player] = nil

	self._gate:forget(player)
end

function ShopService.Destroy(self: Service)
	Scythe.destroy(self._scope)

	for player in self._players do self:OnPlayerRemoving(player) end
end

return ShopService