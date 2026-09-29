local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(script.Parent.Constants)
local Scaling = require(script.Parent.Scaling)
local logger = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Imported"):WaitForChild('Utility'):WaitForChild("Logger"))

local nSettings = Constants.nSettings

local UIBuilder = {}

function UIBuilder.createMainContainer(playerGui: PlayerGui)
	local currentSettings = Scaling.getScaledSettings()

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "NotificationGui"
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local container = Instance.new("Frame")
	container.Name = "MainContainer"
	container.AnchorPoint = Vector2.new(1, 0.5) 
	container.Position = UDim2.fromScale(0.98, 0.5)
	container.Size = UDim2.new(1, 0, 0, 0)
	container.AutomaticSize = Enum.AutomaticSize.Y
	container.BackgroundTransparency = 1
	container.Parent = screenGui

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, currentSettings.Padding * 0.4)
	layout.Parent = container

	return screenGui, container
end

function UIBuilder.createNotificationFrame(notificationType: string, isExecutedFunction: boolean)
	local currentSettings = Scaling.getScaledSettings()
	local lowerType = notificationType:lower()

	local color = nSettings.nColors[lowerType]
	local baseTransparency = nSettings.nAlpha[lowerType]
	local thickness = currentSettings.StrokeThickness
	local cornerRadius = currentSettings.CornerRadius

	local wrapper = Instance.new("Frame")
	wrapper.Name = notificationType:sub(1, 1):upper() .. notificationType:sub(2) .. "_Notification"
	wrapper.BackgroundTransparency = 1
	wrapper.Size = UDim2.fromOffset(0, 0)
	wrapper.AnchorPoint = Vector2.new(0.5, 0.5)
	wrapper.ClipsDescendants = true
	wrapper.LayoutOrder = isExecutedFunction and math.huge or os.time()

	local wrapperCorner = Instance.new("UICorner")
	wrapperCorner.CornerRadius = UDim.new(0, cornerRadius)
	wrapperCorner.Parent = wrapper
	
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundColor3 = color
	inner.BackgroundTransparency = baseTransparency
	inner.Size = UDim2.new(1, -thickness * 2, 1, -thickness * 2)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.ClipsDescendants = true
	inner.ZIndex = 2
	inner.Parent = wrapper
	
	wrapper.Active = true
	inner.Active = true

	local innerCorner = Instance.new("UICorner")
	innerCorner.CornerRadius = UDim.new(0, math.max(0, cornerRadius - thickness))
	innerCorner.Parent = inner
	
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Wraps = true
	layout.Padding = UDim.new(0, currentSettings.Padding * 0.6)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = inner

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, currentSettings.Padding)
	padding.PaddingRight = UDim.new(0, currentSettings.Padding)
	padding.PaddingTop = UDim.new(0, currentSettings.Padding * 0.5)
	padding.PaddingBottom = UDim.new(0, currentSettings.Padding * 0.5)
	padding.Parent = inner

	return wrapper, inner
end

function UIBuilder.createBorderTimer(wrapper: Frame, currentSettings)
	local borderColor = Color3.fromRGB(255, 255, 255)
	local segThickness = currentSettings.CornerRadius

	local topRight = Instance.new("Frame")
	topRight.Name = "TopRight"
	topRight.AnchorPoint = Vector2.new(0, 0)
	topRight.Position = UDim2.fromScale(0.5, 0)
	topRight.Size = UDim2.new(0, 0, 0, segThickness)
	topRight.BackgroundColor3 = borderColor
	topRight.BackgroundTransparency = 0.25
	topRight.BorderSizePixel = 0
	topRight.ZIndex = 1
	topRight.Parent = wrapper

	local right = Instance.new("Frame")
	right.Name = "Right"
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = UDim2.fromScale(1, 0)
	right.Size = UDim2.new(0, segThickness, 0, 0)
	right.BackgroundColor3 = borderColor
	right.BackgroundTransparency = 0.25
	right.BorderSizePixel = 0
	right.ZIndex = 1
	right.Parent = wrapper
	
	local bottom = Instance.new("Frame")
	bottom.Name = "Bottom"
	bottom.AnchorPoint = Vector2.new(1, 1)
	bottom.Position = UDim2.fromScale(1, 1)
	bottom.Size = UDim2.new(0, 0, 0, segThickness)
	bottom.BackgroundColor3 = borderColor
	bottom.BackgroundTransparency = 0.25
	bottom.BorderSizePixel = 0
	bottom.ZIndex = 1
	bottom.Parent = wrapper
	
	local left = Instance.new("Frame")
	left.Name = "Left"
	left.AnchorPoint = Vector2.new(0, 1)
	left.Position = UDim2.fromScale(0, 1)
	left.Size = UDim2.new(0, segThickness, 0, 0)
	left.BackgroundColor3 = borderColor
	left.BackgroundTransparency = 0.25
	left.BorderSizePixel = 0
	left.ZIndex = 1
	left.Parent = wrapper

	local topLeft = Instance.new("Frame")
	topLeft.Name = "TopLeft"
	topLeft.AnchorPoint = Vector2.new(0, 0)
	topLeft.Position = UDim2.fromScale(0, 0)
	topLeft.Size = UDim2.new(0, 0, 0, segThickness)
	topLeft.BackgroundColor3 = borderColor
	topLeft.BackgroundTransparency = 0.25
	topLeft.BorderSizePixel = 0
	topLeft.ZIndex = 1
	topLeft.Parent = wrapper

	return {TopRight = topRight,
		Right = right,
		Bottom = bottom,
		Left = left,
		TopLeft = topLeft,
		SegThickness = segThickness}
end

function UIBuilder.updateBorderProgress(border, progress: number, frameWidth: number, frameHeight: number)
	local seg = border.SegThickness
	local halfW = frameWidth / 2
	local perimeter = halfW + frameHeight + frameWidth + frameHeight + halfW
	local traveled = progress * perimeter
	
	local s1Len = halfW
	local s1 = math.clamp(traveled / s1Len, 0, 1)
	border.TopRight.Size = UDim2.new(0, s1 * halfW, 0, seg)
	
	local s2Len = frameHeight
	local s2 = math.clamp((traveled - s1Len) / s2Len, 0, 1)
	border.Right.Size = UDim2.new(0, seg, 0, s2 * frameHeight)
	
	local s3Len = frameWidth
	local s3 = math.clamp((traveled - s1Len - s2Len) / s3Len, 0, 1)
	border.Bottom.Size = UDim2.new(0, s3 * frameWidth, 0, seg)
	
	local s4Len = frameHeight
	local s4 = math.clamp((traveled - s1Len - s2Len - s3Len) / s4Len, 0, 1)
	border.Left.Size = UDim2.new(0, seg, 0, s4 * frameHeight)
	
	local s5Len = halfW
	local s5 = math.clamp((traveled - s1Len - s2Len - s3Len - s4Len) / s5Len, 0, 1)
	border.TopLeft.Size = UDim2.new(0, s5 * halfW, 0, seg)
end

function UIBuilder.createNotificationContent(inner: Frame, notificationType: string, message: string, isExecutedFunction: boolean, currentSettings, sizeInfo)
	local imageId = nSettings.nImages[notificationType]

	local icon = Instance.new("ImageLabel")
	icon.Image = imageId
	icon.Size = UDim2.fromOffset(currentSettings.ImageSize, currentSettings.ImageSize)
	icon.BackgroundTransparency = 1
	icon.ImageTransparency = 1
	icon.LayoutOrder = 0
	icon.Name = "IconLabel"
	icon:AddTag("UpdateTransparency")
	icon.Parent = inner

	local textLabel = Instance.new("TextLabel")
	textLabel.Text = message
	textLabel.Size = UDim2.new(1, -(currentSettings.ImageSize + currentSettings.Padding * 2), 1, 0)
	textLabel.Position = UDim2.new(0, currentSettings.ImageSize + currentSettings.Padding, 0.5, 0)
	textLabel.AnchorPoint = Vector2.new(0, 0.5)
	textLabel.BackgroundTransparency = 1
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.Font = Constants.nFont
	textLabel.TextSize = sizeInfo.TextSize
	textLabel.TextTransparency = 1
	textLabel.TextWrapped = true
	textLabel.LayoutOrder = isExecutedFunction and 1 or 2
	textLabel:AddTag("UpdateTransparency")
	textLabel.Name = "MessageLabel"
	textLabel.Parent = inner

	local textGradient = Instance.new("UIGradient")
	textGradient.Parent = textLabel

	return {
		Icon = icon,
		TextLabel = textLabel,
		TextGradient = textGradient,
	}
end

return UIBuilder