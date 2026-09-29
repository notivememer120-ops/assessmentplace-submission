local players = game:GetService("Players")
local rep = game:GetService("ReplicatedStorage")

local Scythe = require(rep.Modules.Imported.Utility.Scythe)

local player = players.LocalPlayer

local Bystanders = {}

local prior = {}
local scope
local hiding = false

local function conceal(v)
	if v:IsA("BasePart") or v:IsA("Decal") then
		prior[v] = v.LocalTransparencyModifier
		v.LocalTransparencyModifier = 1
	elseif v:IsA("BillboardGui") or v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then
		prior[v] = v.Enabled
		v.Enabled = false
	elseif v:IsA("Humanoid") then
		prior[v] = v.DisplayDistanceType
		v.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

local function reveal(v, was)
	if v:IsA("BasePart") or v:IsA("Decal") then
		v.LocalTransparencyModifier = was
	elseif v:IsA("Humanoid") then
		v.DisplayDistanceType = was
	else
		v.Enabled = was
	end
end

local function veil(char)
	Scythe.connect(scope, char.DescendantAdded, conceal)

	for _, v in char:GetDescendants() do
		conceal(v)
	end
end

local function watch(plr)
	Scythe.connect(scope, plr.CharacterAdded, veil)

	if plr.Character then
		veil(plr.Character)
	end
end

function Bystanders.hide()
	if hiding then
		warn("Bystanders.hide called while already hiding, ignoring the second call")

		return
	end

	hiding = true
	scope = Scythe.scope()

	Scythe.connect(scope, players.PlayerAdded, watch)

	for _, v in players:GetPlayers() do
		if v ~= player then
			watch(v)
		end
	end
end

function Bystanders.restore()
	if not hiding then
		return
	end

	Scythe.destroy(scope)

	scope = nil

	for k, v in prior do
		reveal(k, v)
	end

	table.clear(prior)

	hiding = false
end

return Bystanders