--!strict
local RagdollRig = {}

function RagdollRig.convert(character: Model): number
	local count = 0
	local joints: {[BasePart]: {[BasePart]: boolean}} = {}

	for _, v in character:GetDescendants() do
		if v:IsA("AnimationConstraint") then
			local attachment0 = v.Attachment0 :: Attachment
			local attachment1 = v.Attachment1 :: Attachment
			local part0 = attachment0.Parent :: BasePart
			local part1 = attachment1.Parent :: BasePart
			local motor = Instance.new("Motor6D")
			motor.Name = v.Name
			motor.Part0 = part0
			motor.Part1 = part1
			motor.C0 = attachment0.CFrame
			motor.C1 = attachment1.CFrame
			motor.Transform = v.Transform
			motor.Parent = v.Parent

			if not joints[part0] then
				joints[part0] = {}
			end

			joints[part0][part1] = true

			v:Destroy()

			count += 1
		end
	end

	if count > 0 then
		for _, v in character:GetDescendants() do
			if v:IsA("BallSocketConstraint") then
				local part0 = (v.Attachment0 :: Attachment):FindFirstAncestorWhichIsA("BasePart") :: BasePart
				local part1 = (v.Attachment1 :: Attachment):FindFirstAncestorWhichIsA("BasePart") :: BasePart

				if (joints[part0] and joints[part0][part1]) or (joints[part1] and joints[part1][part0]) then
					v:Destroy()
				end
			end
		end
	end

	return count
end

return RagdollRig