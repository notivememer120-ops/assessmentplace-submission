local rep = game:GetService("ReplicatedStorage")
local player = game:GetService("Players").LocalPlayer

local WaitFor = require(rep.Modules.Gameplay.WaitFor)
local Scythe = require(rep.Modules.Imported.Utility.Scythe)

local CmdrController = {}
CmdrController.__slittttName = "CmdrController"

function CmdrController:Init()
	self._scope = Scythe.scope()
	self.Cmdr = require(WaitFor:get(rep, "CmdrClient"))

	self.Cmdr:SetActivationKeys({Enum.KeyCode.F2})
	self.Cmdr:SetPlaceName("Game template")

	local function update()
		local allowed = player:GetAttribute("CmdrAllowed") == true

		self.Cmdr:SetEnabled(allowed)

		if not allowed then
			self.Cmdr:Hide()
		end
	end

	Scythe.connect(self._scope, player:GetAttributeChangedSignal("CmdrAllowed"), update)
	update()
end

function CmdrController:Destroy()
	self.Cmdr:SetEnabled(false)
	self.Cmdr:Hide()

	Scythe.destroy(self._scope)
end

return CmdrController