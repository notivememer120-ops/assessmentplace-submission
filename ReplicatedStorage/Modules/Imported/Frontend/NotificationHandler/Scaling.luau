local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local Constants = require(script.Parent.Constants)
local Camera = workspace.CurrentCamera

local Scaling = {}

function Scaling.getDeviceSettings()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		and Constants.device.Mobile
		or Constants.device.Desktop
end

function Scaling.getScaledSettings()
	local viewport = Camera.ViewportSize
	local fontScale = math.clamp(math.min(viewport.X, viewport.Y) / Constants.screenRes, 0.7, 1.3)
	local base = Scaling.getDeviceSettings()

	return {
		MinTextSize = base.MinTextSize,
		MaxTextSize = base.MaxTextSize,
		ImageSize = base.ImageSize * fontScale,
		Padding = base.Padding * fontScale,
		WidthPercentage = base.WidthPercentage,
		MaxWidth = base.MaxWidth,
		Duration = base.Duration,
		CornerRadius = base.CornerRadius * fontScale,
		StrokeThickness = base.StrokeThickness * fontScale,
		FontScale = fontScale,
		ScrollBarThickness = base.ScrollBarThickness,
	}
end

function Scaling.calculateNotificationSize(currentSettings, message: string)
	local screenWidth = Camera.ViewportSize.X
	local fixedWidth = math.min(screenWidth * currentSettings.WidthPercentage, currentSettings.MaxWidth)
	local textAvailableWidth = fixedWidth - (currentSettings.ImageSize + currentSettings.Padding * 3)

	local scaledMin = currentSettings.MinTextSize * currentSettings.FontScale
	local scaledMax = currentSettings.MaxTextSize * currentSettings.FontScale
	local textSize = math.clamp(math.round(scaledMin), scaledMin, scaledMax)

	local textBounds = TextService:GetTextSize(
		message,
		textSize,
		Constants.nFont,
		Vector2.new(textAvailableWidth, math.huge)
	)

	local lineHeight = TextService:GetTextSize(
		"",
		textSize,
		Constants.nFont,
		Vector2.new(math.huge, math.huge)
	).Y

	local totalTextHeight = textBounds.Y + lineHeight

	return {
		Width = fixedWidth,
		Height = math.ceil(math.max(
			totalTextHeight + currentSettings.Padding,
			currentSettings.ImageSize + currentSettings.Padding
			)),
		TextSize = textSize,
	}
end

return Scaling