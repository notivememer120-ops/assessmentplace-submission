--!strict
local rep = game:GetService("ReplicatedStorage")
local Scythe = require(rep.Modules.Imported.Utility.Scythe)

local designW = 1155
local designH = 872
local minFactor = 0.4
local maxFactor = 2.5

local AutoScaleController = {}
AutoScaleController.__slittttName = "AutoScaleController"

type Controller = typeof(AutoScaleController) & {
	_scales: {[UIScale]: string},
	_scope: Scythe.Scope,
	_cameraScope: Scythe.Scope,
}

function AutoScaleController:fit(designSize: Vector2, availableSize: Vector2): number
	return math.min(1, availableSize.X / designSize.X, availableSize.Y / designSize.Y)
end

function AutoScaleController:factor(mode: string?): number
	local v = (workspace.CurrentCamera :: Camera).ViewportSize

	if mode == "hud" then
		return math.clamp(math.min(v.X, v.Y) / 600, 0.7, 1)
	end

	return math.clamp(math.min(v.X / designW, v.Y / designH), minFactor, maxFactor)
end

function AutoScaleController.attach(self: Controller, collector: Instance, mode: string?): UIScale
	if not mode then mode = "viewport" end

	local s = collector:FindFirstChild("AutoScale") :: UIScale?

	if not s then
		s = Instance.new("UIScale")
		s.Name = "AutoScale"
		s.Parent = collector
	end

	local scale = s :: UIScale

	if not self._scales[scale] then
		Scythe.once(self._scope, scale.Destroying, function() self._scales[scale] = nil end)
	end

	self._scales[scale] = mode
	scale.Scale = self:factor(mode)

	return scale
end

function AutoScaleController._apply(self: Controller)
	for s, mode in self._scales do
		s.Scale = self:factor(mode)
	end
end

function AutoScaleController._watch(self: Controller, cam: Camera)
	Scythe.clean(self._cameraScope)
	Scythe.connect(self._cameraScope, cam:GetPropertyChangedSignal("ViewportSize"), function()
		self:_apply()
	end)
end

function AutoScaleController.Init(self: Controller)
	self._scales = {} :: {[UIScale]: string}
	self._scope = Scythe.scope()
	self._cameraScope = Scythe.extend(self._scope)

	self:_watch(workspace.CurrentCamera :: Camera)
	
	Scythe.connect(self._scope, workspace:GetPropertyChangedSignal("CurrentCamera"), function()
		self:_watch(workspace.CurrentCamera :: Camera)
		self:_apply()
	end)

	self:_apply()
end

function AutoScaleController.Destroy(self: Controller)
	Scythe.destroy(self._scope)

	for s in self._scales do s:Destroy() end

	table.clear(self._scales)
end

return AutoScaleController :: Controller