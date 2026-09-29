--!strict
local rep = game:GetService("ReplicatedStorage")
local player = game:GetService("Players").LocalPlayer :: Player

local WaitFor = require(rep.Modules.Gameplay.WaitFor)
local Scythe = require(rep.Modules.Imported.Utility.Scythe)

local WorldGuiController = {}
WorldGuiController.__slittttName = "WorldGuiController"

type WorldGui = BillboardGui | SurfaceGui

type Controller = typeof(WorldGuiController) & {
	_scope: Scythe.Scope,
	_guis: {[string]: WorldGui},
	_holder: typeof(game.StarterGui.WorldGuis),
}

function WorldGuiController.GetGui(self: Controller, name: string): WorldGui
	return self._guis[name]
end

function WorldGuiController._bind(self: Controller, template: WorldGui)
	local gui = Scythe.clone(self._scope, template)
	gui.Adornee = template.Adornee
	gui.Parent = self._holder.Active
	self._guis[template.Name] = gui

	Scythe.connect(self._scope, template:GetPropertyChangedSignal("Adornee"), function()
		gui.Adornee = template.Adornee
	end)
end

function WorldGuiController.Init(self: Controller)
	self._scope = Scythe.scope()
	self._guis = {}
	self._holder = WaitFor:get(player.PlayerGui, "WorldGuis") :: typeof(game.StarterGui.WorldGuis)

	for _, v in rep.Assets.WorldGuiTemplates:GetChildren() do self:_bind((v :: unknown) :: WorldGui) end
end

function WorldGuiController.Destroy(self: Controller)
	Scythe.destroy(self._scope)
	table.clear(self._guis)
end

return WorldGuiController :: Controller