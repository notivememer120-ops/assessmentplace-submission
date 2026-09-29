local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icon = require(ReplicatedStorage.Modules.Imported.Frontend.Icon)
local UILib = require(ReplicatedStorage.Modules.Gameplay.UILib)
local DataService = require(ReplicatedStorage.Modules.Imported.Backend.DataService).client
local Lucide = UILib.Lucide

local shortAttribute = "ServerRegion"
local fullAttribute = "ServerRegionFull"

local ServerRegionDisplay = {}
ServerRegionDisplay.__slittttName = "ServerRegionDisplay"
ServerRegionDisplay.Dependencies = {"SettingsTopbar"}

function ServerRegionDisplay:Init()
	local SettingsTopbar = self:Get("SettingsTopbar")
	local saved = DataService:get({"settings"})
	local asset = Lucide.GetAsset("globe", 48)
	local icon = Icon.new()

	icon:setName("ServerRegion")
	icon:setImage(asset.Url)
	icon:modifyTheme({
		{"IconImage", "ImageRectSize", asset.ImageRectSize},
		{"IconImage", "ImageRectOffset", asset.ImageRectOffset},
	})
	icon:align("Left")
	icon:autoDeselect(false)

	local isExpanded = false

	local function shortLabel()
		return tostring(workspace:GetAttribute(shortAttribute) or "?/?")
	end

	local function fullLabel()
		return `Datacenter location: {workspace:GetAttribute(fullAttribute) or "unknown"}`
	end

	icon:setLabel(shortLabel())

	icon:bindEvent("selected", function()
		isExpanded = true

		icon:setLabel(fullLabel())
	end)

	icon:bindEvent("deselected", function()
		isExpanded = false

		icon:setLabel(shortLabel())
	end)

	workspace:GetAttributeChangedSignal(shortAttribute):Connect(function()
		if not isExpanded then
			icon:setLabel(shortLabel())
		end
	end)

	workspace:GetAttributeChangedSignal(fullAttribute):Connect(function()
		if isExpanded then
			icon:setLabel(fullLabel())
		end
	end)

	icon:setEnabled(saved.showServer)
	SettingsTopbar.Changed:Connect(function(key, value)
		if key == "showServer" then
			icon:setEnabled(value)
		end
	end)
end

return ServerRegionDisplay