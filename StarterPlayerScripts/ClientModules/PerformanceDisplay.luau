local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icon = require(ReplicatedStorage.Modules.Imported.Frontend.Icon)
local UILib = require(ReplicatedStorage.Modules.Gameplay.UILib)
local DataService = require(ReplicatedStorage.Modules.Imported.Backend.DataService).client
local Lucide = UILib.Lucide

local PerfDisplay = {}
PerfDisplay.__slittttName = "PerfDisplay"
PerfDisplay.Dependencies = {"SettingsTopbar"}

local s = 30
local interval = 0.25

function PerfDisplay:Init()
	local SettingsTopbar = self:Get("SettingsTopbar")
	local saved = DataService:get({"settings"})
	local asset = Lucide.GetAsset("activity", 48)
	local chevronRight = Lucide.GetAsset("chevron-right", 48)
	local chevronLeft = Lucide.GetAsset("chevron-left", 48)
	local icon = Icon.new()

	icon:setName("PerfDisplay")
	icon:setImage(asset.Url)
	icon:align("Left")
	icon:autoDeselect(false)

	--icon:disableOverlay(true)

	icon:setImage(chevronRight.Url)
	icon:disableOverlay(true)
	icon:modifyTheme({
		{"IconImage", "Image", chevronRight.Url, "Deselected"},
		{"IconImage", "ImageRectSize", chevronRight.ImageRectSize, "Deselected"},
		{"IconImage", "ImageRectOffset", chevronRight.ImageRectOffset, "Deselected"},

		{"IconImage", "Image", chevronLeft.Url, "Selected"},
		{"IconImage", "ImageRectSize", chevronLeft.ImageRectSize, "Selected"},
		{"IconImage", "ImageRectOffset", chevronLeft.ImageRectOffset, "Selected"},

		{"IconImage", "Image", asset.Url, "Viewing"},
		{"IconImage", "ImageRectSize", asset.ImageRectSize, "Viewing"},
		{"IconImage", "ImageRectOffset", asset.ImageRectOffset, "Viewing"},
	})

	local dtSamples = table.create(s, 1 / 60)
	local sampleIndex = 0
	local hbConn = nil

	local function startTracking()
		if hbConn then return end

		table.move(table.create(s, 1 / 60), 1, s, 1, dtSamples)

		sampleIndex = 0

		local elapsed = 0

		hbConn = RunService.Heartbeat:Connect(function(dt)
			sampleIndex = (sampleIndex % s) + 1
			dtSamples[sampleIndex] = math.min(dt, 0.1)

			elapsed += dt

			if elapsed < interval then return end

			elapsed = 0

			local sum = 0

			for i = 1, s do
				sum += dtSamples[i]
			end

			local fps = math.round(s / sum)

			icon:setLabel(`{fps} FPS`)
		end)
	end

	local function stopTracking()
		if hbConn then
			hbConn:Disconnect()

			hbConn = nil
		end

		icon:setLabel("")
	end

	icon:bindEvent("selected", function()
		startTracking()
	end)

	icon:bindEvent("deselected", function()
		stopTracking()
	end)

	icon:setEnabled(saved.showFps)
	SettingsTopbar.Changed:Connect(function(key, value)
		if key == "showFps" then
			icon:setEnabled(value)
		end
	end)
end

return PerfDisplay