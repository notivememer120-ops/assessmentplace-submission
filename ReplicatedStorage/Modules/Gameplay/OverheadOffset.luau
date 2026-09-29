local overheadClearance = 1
local OverheadOffset = {}

local function partTopY(part)
	local cf = part.CFrame
	local size = part.Size
	local halfHeight = 0.5 * (
		math.abs(cf.RightVector.Y) * size.X
		+ math.abs(cf.UpVector.Y) * size.Y
		+ math.abs(cf.LookVector.Y) * size.Z
	)

	return cf.Position.Y + halfHeight
end

function OverheadOffset.compute(character)
	local head = character:FindFirstChild("Head")

	assert(head, `OverheadOffset.compute: no Head in {character:GetFullName()}`)

	local topY = partTopY(head)

	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Handle" and d.Parent:IsA("Accessory") then
			topY = math.max(topY, partTopY(d))
		end
	end

	return (topY - head.Position.Y) + overheadClearance
end

return OverheadOffset