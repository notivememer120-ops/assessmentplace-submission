local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LoadingScreenEvents = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Gameplay"):WaitForChild("LoadingScreenEvents"))

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local controls = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
local controlsReleased = false

task.spawn(function()
	if not player.Character then
		player.CharacterAdded:Wait()
	end

	if not controlsReleased then
		controls:Disable()
	end
end)

local screen = Instance.new("ScreenGui")
screen.Name = "LoadingScreen"
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.DisplayOrder = 9999
screen.Parent = playerGui

local W, H = 1920, 1080
local viewportResolved = false
local nextX, nextY = 1, 1
local turn = "x"
local phase = "L"
local d, s = 2, 0

local function ensureViewportReady()
	if viewportResolved then return end
	local cam = workspace.CurrentCamera
	local started = os.clock()
	
	while (cam.ViewportSize.X <= 1 or cam.ViewportSize.Y <= 1) and os.clock() - started < 5 do
		cam:GetPropertyChangedSignal("ViewportSize"):Wait()
	end
	
	if cam.ViewportSize.X > 1 and cam.ViewportSize.Y > 1 then
		W, H = math.floor(cam.ViewportSize.X), math.floor(cam.ViewportSize.Y)
	end
	
	viewportResolved = true
end

local function nextPos()
	if phase == "L" then
		local xFull = nextX >= W
		local yFull = nextY >= H
		
		if not (xFull and yFull) then
			local pickX
			if turn == "x" and not xFull then pickX = true
			elseif turn == "y" and not yFull then pickX = false
			elseif not xFull then pickX = true
			else pickX = false
			end

			if pickX then
				local x = nextX
				
				nextX += 1
				turn = "y"
				return x, 0
			else
				local y = nextY
				
				nextY += 1
				turn = "x"
				return 0, y
			end
		end
		
		phase = "diag"
	end

	while d <= W + H - 2 do
		local x, y = d - 1 - s, 1 + s
		s += 1
		
		if s > d - 2 then
			d += 1
			s = 0
		end
		
		if x >= 1 and x < W and y >= 1 and y < H then
			return x, y
		end
	end
	
	return nil
end

local function plantPixel(target, source)
	ensureViewportReady()
	
	local x, y = nextPos()
	if not x then
		warn("preload pixel skipped, viewport full at " .. W .. "x" .. H)
		return nil
	end

	local px
	
	if typeof(source) == "Instance" then
		px = source:Clone()
	else
		px = Instance.new("ImageLabel")
		px.Image = source
	end
	
	px.Size = UDim2.fromOffset(1, 1)
	px.Position = UDim2.fromOffset(x, y)
	px.AnchorPoint = Vector2.new(0, 0)
	px.BackgroundTransparency = 1
	px.BorderSizePixel = 0
	px.ZIndex = 3
	px.Parent = target
	
	return px
end

for _, template in script:GetChildren() do
	if template:IsA("ImageLabel") or template:IsA("ImageButton") then
		plantPixel(screen, template)
	end
end

local base = Instance.new("ImageLabel")
base.Name = "Base"
base.Image = ""
base.ImageColor3 = Color3.fromRGB(255, 255, 255)
base.ScaleType = Enum.ScaleType.Stretch
base.Size = UDim2.fromScale(1, 1)
base.BackgroundTransparency = 1
base.BorderSizePixel = 0
base.Parent = screen
base.ScaleType = Enum.ScaleType.Crop

local overlay = Instance.new("Frame")
overlay.Name = "GradientOverlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
overlay.BackgroundTransparency = 0
overlay.BorderSizePixel = 0
overlay.ZIndex = 2
overlay.Parent = screen

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
	ColorSequenceKeypoint.new(0.470, Color3.fromRGB(2, 1, 5)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
})

gradient.Transparency = NumberSequence.new(0)

task.delay(2, function()
	local proxy = Instance.new("NumberValue")
	proxy.Value = 0
	proxy:GetPropertyChangedSignal("Value"):Connect(function()
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.305, 0),
			NumberSequenceKeypoint.new(1, proxy.Value),
		})
	end)
	
	local info = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(proxy, info, {Value = 0.481}):Play()
end)

gradient.Rotation = -56
gradient.Parent = overlay

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Text = "Loading screen"
title.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
title.TextColor3 = Color3.fromRGB(245, 240, 255)
title.TextScaled = true
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextYAlignment = Enum.TextYAlignment.Center
title.BackgroundTransparency = 1
title.AnchorPoint = Vector2.new(0, 1)
title.Position = UDim2.new(0.018, 0, 0.96, 0)
title.Size = UDim2.new(0.8, 0, 0.248, 0)
title.ZIndex = 2
title.Parent = screen

local titleStroke = Instance.new("UIStroke")
titleStroke.Color = Color3.fromRGB(117, 47, 47)
titleStroke.Thickness = 0.05
titleStroke.Transparency = 0.3
titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
titleStroke.LineJoinMode = Enum.LineJoinMode.Round
titleStroke.Parent = title

local desc = Instance.new("TextLabel")
desc.Name = "Description"
desc.Text = "Loading..."
desc.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
desc.TextColor3 = Color3.fromRGB(255, 255, 255)
desc.TextTransparency = 0.5
desc.TextScaled = true
desc.TextXAlignment = Enum.TextXAlignment.Left
desc.TextYAlignment = Enum.TextYAlignment.Center
desc.BackgroundTransparency = 1
desc.AnchorPoint = Vector2.new(0, 1)
desc.Position = UDim2.new(0.018, 0, 0.972, 0)
desc.Size = UDim2.new(0.334, 0, 0.044, 0)
desc.ZIndex = 2
desc.Parent = screen

local active = true
local maxSeen = 0

task.spawn(function()
	while active do
		local current = ContentProvider.RequestQueueSize
		if current > maxSeen then maxSeen = current end
		if maxSeen > 0 then
			local loaded = math.max(maxSeen - current, 0)
			desc.Text = string.format("Loading... (%d/%d)", loaded, maxSeen)
		end
		task.wait(0.1)
	end
end)

--if not game:IsLoaded() then
--	game.Loaded:Wait()
--end

--task.wait(math.random(6, 10))

-- lifting on the timer alone revealed a UI-less world whenever player data came in
-- slow (framework boot waits on it); hold until the client booted, capped so a stuck
-- boot can't park anyone on black forever
local heldSince = os.clock()

while not LoadingScreenEvents.ClientReady and os.clock() - heldSince < 45 do
	task.wait(0.25)
end

active = false
if maxSeen > 0 then
	desc.Text = string.format("Loading... (%d/%d)", maxSeen, maxSeen)
end

local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
TweenService:Create(base, fadeInfo, {ImageTransparency = 1}):Play()
TweenService:Create(overlay, fadeInfo, {BackgroundTransparency = 1}):Play()
TweenService:Create(title, fadeInfo, {TextTransparency = 1}):Play()
TweenService:Create(titleStroke, fadeInfo, {Transparency = 1}):Play()
local descTween = TweenService:Create(desc, fadeInfo, {TextTransparency = 1})
descTween:Play()

LoadingScreenEvents.AboutToHide:Fire()
LoadingScreenEvents.HasHidden = true

descTween.Completed:Wait()

controlsReleased = true
controls:Enable()
screen:Destroy()