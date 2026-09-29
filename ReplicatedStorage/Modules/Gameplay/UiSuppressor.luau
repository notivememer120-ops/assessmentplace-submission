--!strict
local players = game:GetService("Players")
local rep = game:GetService("ReplicatedStorage")
local starterGui = game:GetService("StarterGui")

local Icon = require(rep.Modules.Imported.Frontend.Icon)

local player = players.LocalPlayer :: Player

local UiSuppressor = {}

local hidden: {LayerCollector} = {}
local coreState: {[Enum.CoreGuiType]: boolean} = {}
local suppressing = false

function UiSuppressor.hide(keep: LayerCollector)
	if suppressing then
		warn("UiSuppressor.hide called while already suppressing, ignoring the second call")

		return
	end

	suppressing = true

	local topbar: {[LayerCollector]: boolean} = {}
	local containers: {[string]: ScreenGui} = (Icon :: any).container

	for _, v in containers do
		topbar[v] = true
	end

	for _, v in player.PlayerGui:GetChildren() do
		if v:IsA("LayerCollector") and v.Enabled and v ~= keep and not topbar[v] then
			table.insert(hidden, v)

			v.Enabled = false
		end
	end

	if #hidden == 0 then
		warn("UiSuppressor.hide disabled nothing, PlayerGui had no other enabled LayerCollector")
	end

	for _, v in Enum.CoreGuiType:GetEnumItems() do
		if v ~= Enum.CoreGuiType.All then
			coreState[v] = starterGui:GetCoreGuiEnabled(v)

			starterGui:SetCoreGuiEnabled(v, false)
		end
	end
end

function UiSuppressor.restore()
	if not suppressing then
		return
	end

	for _, v in hidden do
		v.Enabled = true
	end

	for t, was in coreState do
		starterGui:SetCoreGuiEnabled(t, was)
	end

	table.clear(hidden)
	table.clear(coreState)

	suppressing = false
end

return UiSuppressor