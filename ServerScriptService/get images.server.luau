local replicatedFirst = game:GetService("ReplicatedFirst")

local loadingScreen = replicatedFirst:FindFirstChild("LoadingScreen")
local function imageOf(inst)
	local s, img = pcall(function()
		return inst.Image
	end)

	if s and type(img) == "string" and img ~= "" then
		return img
	end 

	return nil
end

local seen = {}

for _, child in loadingScreen:GetChildren() do
	local img = imageOf(child)
	if img then
		seen[img] = true
	end
end

local added = 0

for _, inst in game:GetDescendants() do
	local img = imageOf(inst)

	if not img or seen[img] then
		continue
	end

	seen[img] = true

	local holder = Instance.new("ImageLabel")
	holder.Name = img
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Image = img
	holder.Parent = loadingScreen

	added += 1
end

print(`collected {added} unique images into {loadingScreen:GetFullName()}`)