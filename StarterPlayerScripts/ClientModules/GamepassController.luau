--!strict
local rep = game:GetService("ReplicatedStorage")

local GamepassPackets = require(rep.Modules.Packets.GamepassPackets)
local Signal = require(rep.Modules.Imported.Utility.Signal)

local OwnershipSync = GamepassPackets.packets.OwnershipSync
local RequestOwnership = GamepassPackets.packets.RequestOwnership

type Controller = {
	__slittttName: string,
	_owned: {[string]: boolean},
	OwnershipChanged: typeof(Signal()),
	Init: (Controller) -> (),
	Owns: (Controller, string) -> boolean,
}

local GamepassController = {} :: Controller
GamepassController.__slittttName = "GamepassController"

function GamepassController:Init()
	self._owned = {}
	self.OwnershipChanged = Signal()

	OwnershipSync.listen(function(data)
		local owned = {}
		
		for _, key in data.passes do
			owned[key] = true
		end
		
		self._owned = owned

		self.OwnershipChanged:Fire()
	end)

	RequestOwnership.send()
end

function GamepassController:Owns(key)
	return self._owned[key] == true
end

return GamepassController