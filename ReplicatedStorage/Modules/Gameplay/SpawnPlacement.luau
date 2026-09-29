--!strict
local SpawnPlacement = {}

function SpawnPlacement.place(model: Model, point: BasePart)
	local box
	local size

	box, size = model:GetBoundingBox()

	local offset = model:GetPivot():ToObjectSpace(box)
	local target = point.CFrame * CFrame.new(0, (point.Size.Y + size.Y) / 2, 0)

	model:PivotTo(target * offset:Inverse())

	for _, v in model:GetDescendants() do
		if v:IsA("BasePart") then
			v.AssemblyLinearVelocity = Vector3.zero
			v.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

return SpawnPlacement