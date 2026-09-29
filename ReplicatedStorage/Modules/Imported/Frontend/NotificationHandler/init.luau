local notificationHandler = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Imported = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Imported")
local Scythe = require(Imported:WaitForChild('Utility'):WaitForChild("Scythe"))
local InputDetector = require(Imported:WaitForChild('Utility'):WaitForChild("InputDetector"))
local logger = require(Imported:WaitForChild('Utility'):WaitForChild("Logger"))

local K = require(script.Constants)
local Scaling = require(script.Scaling)
local UIBuilder = require(script.UIBuilder)

local nSettings = K.nSettings
local animSettings = K.animSettings

local Camera = workspace.CurrentCamera
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local containerScope = nil

local v = {}

for _, t in nSettings.nTypes do
	v[t:lower()] = true
end

local segments = {TopRight = true, Right = true, Bottom = true, Left = true, TopLeft = true}

local function updateFrameTransparency(wrapper:Frame)
	local inner = wrapper:FindFirstChild("Inner")

	local viewportHeight = Camera.ViewportSize.Y
	local startY = viewportHeight * K.yFade
	local endY = viewportHeight * K.yFadeEnd
	local frameBottomY = wrapper.AbsolutePosition.Y + wrapper.AbsoluteSize.Y
	local transparency = frameBottomY > startY and 0 or math.clamp((startY - frameBottomY) / (startY - endY), 0, 1)
	local typeMatch = wrapper.Name:match("^(%a+)_Notification")

	if not typeMatch then
		logger.warn("frame name doesnt match notification pattern:", wrapper.Name)
		return
	end

	local notificationType = typeMatch:lower()
	inner.BackgroundTransparency = nSettings.nAlpha[notificationType] + transparency * (1 - nSettings.nAlpha[notificationType])

	for _, child in ipairs(inner:GetDescendants()) do
		if not child:HasTag("UpdateTransparency") then
			continue
		end

		if child:IsA("ImageLabel") then
			child.ImageTransparency = transparency

		elseif child:IsA("TextLabel") then
			child.TextTransparency = transparency

		elseif child:IsA("Frame") then
			child.BackgroundTransparency = transparency
		end
	end

	for _, child in ipairs(wrapper:GetChildren()) do
		if child:IsA("Frame") and segments[child.Name] then
			child.BackgroundTransparency = 0.25 + transparency * 0.75
		end
	end
end

local function animateGradientTransparency(scope, uiGradient:UIGradient, duration:number)
	if not uiGradient or not uiGradient:IsA("UIGradient") then
		logger.warn("gradient is missing or wrong type, skipping reveal animation")
		return
	end

	local numKeypoints = 20
	local startTime = tick()

	local connection
	connection = Scythe.connect(scope, RunService.Heartbeat, function()
		local currentElapsedTime = tick() - startTime
		local progress = math.clamp(currentElapsedTime / duration, 0, 1)

		local keypoints = {}

		for i = 0, numKeypoints - 1 do
			local fadeStartTime = (i / numKeypoints)
			local fadeProgress = math.clamp((progress - fadeStartTime) * numKeypoints, 0, 1)

			local transparencyValue = 1 - fadeProgress
			table.insert(keypoints, NumberSequenceKeypoint.new(i / (numKeypoints - 1), transparencyValue))
		end

		uiGradient.Transparency = NumberSequence.new(keypoints)

		if progress >= 1 then
			Scythe.discard(scope, connection)
			uiGradient:Destroy()
		end
	end)
end

local function resizeAllNotifications()
	local gui = playerGui:FindFirstChild("NotificationGui")
	local container = gui:FindFirstChild("MainContainer")

	local currentSettings = Scaling.getScaledSettings()
	container.UIListLayout.Padding = UDim.new(0, currentSettings.Padding * 0.4)

	for _, wrapper in ipairs(container:GetChildren()) do
		if not wrapper:IsA("Frame") then continue end 
		local inner = wrapper:FindFirstChild("Inner")

		if inner:FindFirstChild("MessageInput") then
			continue
		end

		local textLabel = inner:FindFirstChild("MessageLabel")
		local sizeInfo = Scaling.calculateNotificationSize(currentSettings, textLabel.Text)
		local thickness = currentSettings.StrokeThickness
		local cornerRadius = currentSettings.CornerRadius

		local wrapperCorner = wrapper:FindFirstChild("UICorner")
		wrapperCorner.CornerRadius = UDim.new(0, cornerRadius)
		inner.Size = UDim2.new(1, -thickness * 2, 1, -thickness * 2)

		local innerCorner = inner:FindFirstChild("UICorner")
		innerCorner.CornerRadius = UDim.new(0, math.max(0, cornerRadius - thickness))

		local padding = inner:FindFirstChild("UIPadding")
		padding.PaddingLeft = UDim.new(0, currentSettings.Padding)
		padding.PaddingRight = UDim.new(0, currentSettings.Padding)
		padding.PaddingTop = UDim.new(0, currentSettings.Padding * 0.5)
		padding.PaddingBottom = UDim.new(0, currentSettings.Padding * 0.5)

		local iconLabel = inner:FindFirstChild("IconLabel")

		iconLabel.Size = UDim2.fromOffset(currentSettings.ImageSize, currentSettings.ImageSize)
		textLabel.TextSize = sizeInfo.TextSize
		textLabel.Size = UDim2.new(1, -(currentSettings.ImageSize + currentSettings.Padding * 2), 1, 0)

		local segThickness = cornerRadius

		for _, child in ipairs(wrapper:GetChildren()) do
			if child:IsA("Frame") and segments[child.Name] then
				local size = child.Size

				if child.Name == "TopRight" or child.Name == "Bottom" or child.Name == "TopLeft" then
					child.Size = UDim2.new(0, size.X.Offset, 0, segThickness)
				else
					child.Size = UDim2.new(0, segThickness, 0, size.Y.Offset)
				end
			end
		end

		TweenService:Create(wrapper, animSettings, {Size = UDim2.fromOffset(sizeInfo.Width, sizeInfo.Height)}):Play()
	end
end

local function playSound_impl(notificationType:string)
	local notificationsFolder = SoundService:FindFirstChild("Notifications")
	local soundName = nSettings.nSounds[notificationType:lower()]
	local sourceSound = notificationsFolder:FindFirstChild(soundName)

	local sound = sourceSound:Clone()
	sound.Parent = SoundService
	sound:Play()

	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

local function animateOut(wrapper, callback)
	local tween = TweenService:Create(wrapper, animSettings, {Size = UDim2.fromOffset(0, 0)})

	tween.Completed:Connect(function()
		wrapper:Destroy()

		if callback then
			callback()
		end
	end)

	tween:Play()
end

local function ensureContainer()
	local existingGui = playerGui:FindFirstChild("NotificationGui")

	if existingGui and containerScope then
		return existingGui.MainContainer
	end

	if containerScope then Scythe.destroy(containerScope) end
	containerScope = Scythe.scope()

	local screenGui, container = UIBuilder.createMainContainer(playerGui)

	Scythe.add(containerScope, screenGui)
	Scythe.connect(containerScope, RunService.Heartbeat, function()
		for _, wrapper in ipairs(container:GetChildren()) do
			if wrapper:IsA("Frame") and wrapper.Name:find("_Notification") then
				updateFrameTransparency(wrapper)
			end
		end
	end)

	Scythe.connect(containerScope, Camera:GetPropertyChangedSignal("ViewportSize"), resizeAllNotifications)

	return container
end

local function showNotification(notificationType: string, message: string, duration: number?, executedFunction: (() -> ())?, playSound: boolean?)
	local isExecutedFunction = executedFunction and true or false
	notificationType = notificationType:lower()

	local currentSettings = Scaling.getScaledSettings()
	local container = ensureContainer()
	local sizeInfo = Scaling.calculateNotificationSize(currentSettings, message)

	local wrapper, inner = UIBuilder.createNotificationFrame(notificationType, isExecutedFunction)
	local content = UIBuilder.createNotificationContent(inner, notificationType, message, isExecutedFunction, currentSettings, sizeInfo)

	local border = nil

	if not isExecutedFunction then
		border = UIBuilder.createBorderTimer(wrapper, currentSettings)
	end

	wrapper.Parent = container

	if playSound == nil or playSound == true then
		playSound_impl(notificationType)
	end

	local notificationTime = duration or currentSettings.Duration
	local owner = containerScope
	local notifScope = Scythe.extend(owner)
	local closing = false

	local function closeNotification()
		if closing or not Scythe.isAlive(owner) or not Scythe.isAlive(notifScope) then return end
		closing = true
		Scythe.discard(owner, notifScope)

		TweenService:Create(content.Icon, animSettings, {ImageTransparency = 1}):Play()
		TweenService:Create(content.TextLabel, animSettings, {TextTransparency = 1}):Play()

		animateOut(wrapper, function()
			if containerScope == owner and container.Parent and #container:GetChildren() == 1 then
				containerScope = nil
				Scythe.destroy(owner)
			end
		end)
	end

	animateGradientTransparency(notifScope, content.TextGradient, animSettings.Time * 1.5)
	TweenService:Create(wrapper, animSettings, {Size = UDim2.fromOffset(sizeInfo.Width, sizeInfo.Height)}):Play()
	TweenService:Create(content.Icon, animSettings, {ImageTransparency = 0}):Play()
	TweenService:Create(content.TextLabel, animSettings, {TextTransparency = 0}):Play()

	if executedFunction then
		task.spawn(function()
			local ok, err = pcall(executedFunction)

			if not ok then
				logger.warn("notification callback errored:", err)
			end

			closeNotification()
		end)
	else
		local paused = false
		local detector = Scythe.add(notifScope, InputDetector.new(wrapper), "destroy")

		wrapper.Active = true
		inner.Active = true

		detector:onHoverStart(function()
			paused = true
		end)

		detector:onHoverEnd(function()
			paused = false
		end)

		Scythe.connect(notifScope, inner.MouseEnter, function()
			paused = true
		end)

		Scythe.connect(notifScope, inner.MouseLeave, function()
			paused = false
		end)

		Scythe.connect(notifScope, inner.InputBegan, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				closeNotification()
			end
		end)

		local remainingTime = notificationTime
		Scythe.connect(notifScope, RunService.Heartbeat, function(dt)
			if paused then
				return
			end

			remainingTime = remainingTime - dt

			local progress = math.clamp(1 - remainingTime / notificationTime, 0, 1)
			local frameWidth = wrapper.AbsoluteSize.X
			local frameHeight = wrapper.AbsoluteSize.Y

			if border and frameWidth > 0 and frameHeight > 0 then
				UIBuilder.updateBorderProgress(border, progress, frameWidth, frameHeight)
			end

			if remainingTime <= 0 then
				closeNotification()
			end
		end)
	end
end

function notificationHandler:CreateNotification(notificationType: string, message: string, duration: number?, executedFunction: (() -> ())?, playSound: boolean?)
	showNotification(notificationType, message, duration, executedFunction, playSound)
end

function notificationHandler:ClearNotifications()
	if containerScope then
		local owner = containerScope
		containerScope = nil
		Scythe.destroy(owner)
	end
end

return notificationHandler