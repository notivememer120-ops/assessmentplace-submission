--!strict
local rep = game:GetService("ReplicatedStorage")
local Scythe = require(rep.Modules.Imported.Utility.Scythe)

local ViewportPreview = {}
ViewportPreview.__index = ViewportPreview

type Viewport = ViewportFrame & {WorldModel: WorldModel}

type State = {
	scope: Scythe.Scope,
	content: Scythe.Scope,
	viewport: Viewport,
	camera: Camera,
	model: Model?,
}

export type Preview = typeof(setmetatable({} :: State, ViewportPreview))

function ViewportPreview.new(viewport: Viewport): Preview
	local self = setmetatable({} :: State, ViewportPreview)
	self.scope = Scythe.scope()
	self.content = Scythe.extend(self.scope)
	self.viewport = viewport
	self.camera = Scythe.add(self.scope, Instance.new("Camera"))
	self.camera.Name = "PreviewCamera"
	self.camera.FieldOfView = viewport:GetAttribute("FieldOfView") :: number
	self.camera.Parent = viewport
	viewport.CurrentCamera = self.camera

	Scythe.connect(self.scope, viewport:GetPropertyChangedSignal("AbsoluteSize"), function() self:Fit() end)
	return self
end

function ViewportPreview.Set(self: Preview, template: Model)
	Scythe.clean(self.content)

	local model = Scythe.clone(self.content, template)

	self.model = model
	model.Parent = self.viewport.WorldModel
	model:PivotTo(CFrame.identity)
	self:Fit()
end

function ViewportPreview.Fit(self: Preview)
	if not self.model then return end

	local bounds = self.model:GetBoundingBox()
	local size = select(2, self.model:GetBoundingBox())
	local angles = self.model:GetAttribute("PreviewAngles") :: Vector3
	local rotation = CFrame.fromOrientation(math.rad(angles.X), math.rad(angles.Y), math.rad(angles.Z))
	local aspect = self.viewport.AbsoluteSize.X / math.max(1, self.viewport.AbsoluteSize.Y)
	local half = math.tan(math.rad(self.camera.FieldOfView / 2))
	local distance = 0

	for x = -1, 1, 2 do
		for y = -1, 1, 2 do
			for z = -1, 1, 2 do
				local point = rotation:VectorToObjectSpace(bounds:VectorToWorldSpace(size * Vector3.new(x, y, z) / 2))

				distance = math.max(distance, point.Z + math.max(math.abs(point.X) / math.max(0.1, aspect * half), math.abs(point.Y) / half))
			end
		end
	end

	self.camera.CFrame = CFrame.new(bounds.Position) * rotation * CFrame.new(0, 0, distance * 1.12)
	self.camera.Focus = CFrame.new(bounds.Position)
end

function ViewportPreview.Clear(self: Preview)
	Scythe.clean(self.content)

	self.model = nil
end

function ViewportPreview.Destroy(self: Preview)
	Scythe.destroy(self.scope)

	self.viewport.CurrentCamera = nil :: any
end

return ViewportPreview