local UIAnimator = {}

-------------------// SERVICES \\--------------------

local TextService = game:GetService("TextService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local TS = game:GetService("TweenService")
local Players = game:GetService("Players")

---------------------// PLAYER \\--------------------

local player: Player = Players.LocalPlayer

----------------------// UI \\-----------------------

local PlayerGui = player:WaitForChild("PlayerGui")

-------------------// MODULES \\---------------------

local EasyVisuals = require(RS.Modules.Imported.Utility.EasyVisuals)
local Scythe = require(RS.Modules.Imported.Utility.Scythe)
local Mods = require(RS.Modules.Imported.Utility.Mods)

-----------------// EXPORT TYPES \\------------------

export type CameraProps = {
	fovIn: number?,     -- FOV to zoom into, default 60
	position: Vector3?, -- world position to move camera to
	rotation: CFrame?,  -- full CFrame rotation (ignores position if CFrame is set)
}

export type ShowTextOptions = {
	effect: ("Typewriter" | "Jitter" | "PlopIn" | "Bubbly" | "Glitch" | "FadeIn")?,
	interval: number?,
	speed: number?,
	intensity: number?,
	onComplete: (() -> ())?
}

------------------// REFERENCES \\-------------------

--// Folders
local TextPresets = script.Presets.Text
local HoverPresets = script.Presets.Hover
local PressPresets = script.Presets.Press

--// Constants
local RIPPLE_ENABLED = script:GetAttribute("RippleEnabled") ~= false
local RIPPLE_COLOR = script:GetAttribute("RippleColor") or Color3.fromRGB(255, 255, 255)
local RIPPLE_SIZE = script:GetAttribute("RippleSize") or 50
local RIPPLE_FADE_TIME = script:GetAttribute("RippleFadeTime") or 0.2

--// Variables
local tr = Scythe.scope()
local textScopes = {}

local blurSize = 15

local originalFov = nil
local originalCFrame = nil
local blur = nil

local IconRegistry = {}
local cameraProps = {}

----------------// PRIV. FUNCTIONS \\----------------

-- Controls the on screen ripple effect when clicking
local function checkForRipple()
	if RIPPLE_ENABLED then
		local inset = game:GetService("GuiService"):GetGuiInset()
		local rippleGui = Instance.new("ScreenGui")
		rippleGui.Name = "RippleGui"
		rippleGui.IgnoreGuiInset = false
		rippleGui.DisplayOrder = 999
		rippleGui.ResetOnSpawn = false
		rippleGui.Parent = PlayerGui

		UIS.InputBegan:Connect(function(input, gameProcessed)
			local isClick = input.UserInputType == Enum.UserInputType.MouseButton1
			local isTouch = input.UserInputType == Enum.UserInputType.Touch
			local isGamepad = input.UserInputType == Enum.UserInputType.Gamepad1
				and input.KeyCode == Enum.KeyCode.ButtonA

			if not (isClick or isTouch or isGamepad) then return end

			local screenPos
			if isGamepad then
				local viewport = workspace.CurrentCamera.ViewportSize
				screenPos = Vector2.new(viewport.X / 2, viewport.Y / 2)
			else
				screenPos = Vector2.new(input.Position.X, input.Position.Y)
			end

			local ripple = Instance.new("Frame")
			ripple.Size = UDim2.new(0, 0, 0, 0)
			ripple.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y)
			ripple.AnchorPoint = Vector2.new(0.5, 0.5)
			ripple.BackgroundColor3 = RIPPLE_COLOR
			ripple.BackgroundTransparency = 0.6
			ripple.BorderSizePixel = 0
			ripple.ZIndex = 999

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = ripple
			ripple.Parent = rippleGui

			local tweenInfo = TweenInfo.new(RIPPLE_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local targetSize = UDim2.new(0, RIPPLE_SIZE, 0, RIPPLE_SIZE)

			TS:Create(ripple, tweenInfo, {Size = targetSize}):Play()
			local fadeTween = TS:Create(ripple, tweenInfo, {BackgroundTransparency = 1})
			fadeTween:Play()
			fadeTween.Completed:Once(function()
				ripple:Destroy()
			end)
		end)
	end
end

-- Controls lighting blur
local function setBlur(enabled: boolean)
	if enabled then
		if not blur then
			blur = Instance.new("BlurEffect")
			blur.Size = blurSize
			blur.Parent = Lighting
		end
	else
		if blur then
			blur:Destroy()
			blur = nil
		end
	end
end

-- Tweens element size up on hover and down on click
local function animateHover(element: Instance, scalePercent: number?)
	if element:GetAttribute("HoverConnected") then return end
	element:SetAttribute("HoverConnected", true)

	local hoverType = element:GetAttribute("HoverType") or "Grow"
	local pressType = element:GetAttribute("PressType") or "Shrink"
	local hoverIntensity = element:GetAttribute("HoverIntensity") or scalePercent or 5
	local pressIntensity = element:GetAttribute("PressIntensity") or 10

	local hoverPreset = require(HoverPresets:FindFirstChild(hoverType))
	local pressPreset = require(PressPresets:FindFirstChild(pressType))

	local hover = hoverPreset(element, TS, hoverIntensity)
	local press = pressPreset(element, TS, pressIntensity)

	element.MouseEnter:Connect(hover.onEnter)
	element.MouseLeave:Connect(hover.onLeave)
	element.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			Mods.PlaySingleSound(RS.Assets.Sounds.SFX.UiClickOptionClick)
			press.onPress()
		end
	end)
	element.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			press.onRelease()
		end
	end)
end

-- Sets visibility to true for tagged elements
local function showUiElements()
	for _, element in CS:GetTagged("HideableUI") do
		element.Visible = true
	end
end

-- Sets visibility to false for tagged elements
local function hideUiElements()
	for _, element in CS:GetTagged("HideableUI") do
		element.Visible = false
	end
end

local function safeTween(obj, info, goals)
	local tween = TS:Create(obj, info, goals)
	tween:Play()
	return tween
end

-- Builds transparency goals for fade in/out on a single object
local function buildTransparencyGoals(obj: Instance, fadingIn: boolean, isRoot: boolean)
	local goals = {}

	if obj:IsA("GuiObject") then
		if not obj:IsA("TextLabel") and not obj:IsA("TextButton") and not obj:IsA("TextBox") and not obj:IsA("ImageLabel") and not obj:IsA("ImageButton") then
			local orig = obj:GetAttribute("OriginalBGTransparency")
			if not orig then
				orig = obj.BackgroundTransparency
				obj:SetAttribute("OriginalBGTransparency", orig)
			end
			goals.BackgroundTransparency = fadingIn and orig or 1
		end
	end
	if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
		local origBG = obj:GetAttribute("OriginalBGTransparency")
		if not origBG then
			origBG = obj.BackgroundTransparency
			obj:SetAttribute("OriginalBGTransparency", origBG)
		end
		local origText = obj:GetAttribute("OriginalTextTransparency")
		if not origText then
			origText = obj.TextTransparency
			obj:SetAttribute("OriginalTextTransparency", origText)
		end
		goals.BackgroundTransparency = fadingIn and origBG or 1
		goals.TextTransparency = fadingIn and origText or 1
	end
	if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
		local origBG = obj:GetAttribute("OriginalBGTransparency")
		if not origBG then
			origBG = obj.BackgroundTransparency
			obj:SetAttribute("OriginalBGTransparency", origBG)
		end
		local origImg = obj:GetAttribute("OriginalImageTransparency")
		if not origImg then
			origImg = obj.ImageTransparency
			obj:SetAttribute("OriginalImageTransparency", origImg)
		end
		goals.BackgroundTransparency = fadingIn and origBG or 1
		goals.ImageTransparency = fadingIn and origImg or 1
	end
	if obj:IsA("UIStroke") then
		local orig = obj:GetAttribute("OriginalStrokeTransparency")
		if not orig then
			orig = obj.Transparency
			obj:SetAttribute("OriginalStrokeTransparency", orig)
		end
		goals.Transparency = fadingIn and orig or 1
	end

	return goals
end

-- Reads common attributes and args shared across most animation functions
local function resolveAnimArgs(element: Instance, speed: number?, blurEnabled: boolean?, hideOtherUi: boolean?)
	return {
		speed = speed or element:GetAttribute("Speed") or 0.5,
		blur = blurEnabled or element:GetAttribute("Blur") or false,
		hideUi = hideOtherUi or element:GetAttribute("HideUI") or false,
	}
end

-- Sets camera properties
local function setCamera(enabled: boolean)
	local Camera = workspace.CurrentCamera
	local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.In)

	if enabled then
		originalFov = Camera.FieldOfView
		originalCFrame = Camera.CFrame

		local goals = {FieldOfView = cameraProps.fovIn or 60}

		if cameraProps.rotation then
			goals.CFrame = cameraProps.rotation
		elseif cameraProps.position then
			goals.CFrame = CFrame.new(cameraProps.position) * CFrame.Angles(originalCFrame:ToEulerAnglesXYZ())
		end

		TS:Create(Camera, tweenInfo, goals):Play()
	else
		local goals = {FieldOfView = originalFov or 70}
		if originalCFrame then goals.CFrame = originalCFrame end

		TS:Create(Camera, tweenInfo, goals):Play()
		originalFov = nil
		originalCFrame = nil
	end
end

-- Applies blur and UI hiding based on args
local function applyEntryEffects(args)
	setBlur(args.blur)
	setCamera(true)
	if args.hideUi then hideUiElements() end
end

local function applyExitEffects(args)
	setBlur(false)
	setCamera(false)
	showUiElements()
end

-- Walks an element and its descendants applying fade goals
local function applyFadeToElement(element: Instance, tweenInfo: TweenInfo, fadingIn: boolean)
	local function fadeObject(obj: Instance, isRoot: boolean)
		local goals = buildTransparencyGoals(obj, fadingIn, isRoot)
		if next(goals) then
			task.spawn(function()
				safeTween(obj, tweenInfo, goals)
			end)
		end
	end

	fadeObject(element, true)
	for _, descendant in ipairs(element:GetDescendants()) do
		fadeObject(descendant, false)
	end
end

---- Plays hover and click sounds for buttons (Automatic behavior)
--local function playHoverSound(element)
--	if element:IsA("ImageButton") or element:IsA("TextButton") then
--		if element:GetAttribute("AudioConnected") then return end
--		element:SetAttribute("AudioConnected", true)

--		element.MouseEnter:Connect(function()
--			if SFX.UI_Hover then SFX.UI_Hover:Play() end
--		end)
--		element.MouseButton1Click:Connect(function()
--			if SFX.UI_Click then SFX.UI_Click:Play() end
--		end)
--	end
--end

-- Applies visual effects from EasyVisuals package
local function addSpecialEffect(item: Instance)
	if not item:GetAttribute("EffectType") then return end

	local effectType = item:GetAttribute("EffectType")
	if not effectType then warn("[UIAnimator].addSpecialEffect() Attribute 'EffectType' not found for UI instance:", item) return end

	local speed = item:GetAttribute("EffectSpeed") or 0.35
	local size = item:GetAttribute("EffectSize") or 1

	EasyVisuals.new(item, effectType, speed, size)
end

-- Rotates UI elements continuously
local function spinUI(item: Instance)
	if item:GetAttribute("Spinning") then return end
	item:SetAttribute("Spinning", true)

	task.spawn(function()
		while item and item.Parent do
			item.Rotation = -180
			local anim = TS:Create(item, TweenInfo.new(9, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {Rotation = 180})
			anim:Play()

			local completed = false
			anim.Completed:Once(function() completed = true end)
			repeat task.wait() until completed or not item.Parent

			anim:Cancel()
		end
	end)
end

-- Rotates gradients based on attribute speed
local function spinGradient(gradient: UIGradient)
	if not gradient:IsA("UIGradient") then return end

	local rotationSpeed = gradient:GetAttribute("RotateSpeed") or 7
	local tweenInfo = TweenInfo.new(rotationSpeed, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false, 0)

	gradient.Rotation = -180
	local tween = TS:Create(gradient, tweenInfo, {Rotation = 180})
	tween:Play()

	gradient.Destroying:Connect(function()
		tween:Cancel()
	end)
end

-- Adjusts text size based on screen resolution
local function setupResponsiveText(textLabel: TextLabel)
	local viewportSize = workspace.CurrentCamera.ViewportSize
	local scaleFactor = math.min(viewportSize.X / 1920, viewportSize.Y / 1080)

	if textLabel and (textLabel:IsA("TextLabel") or textLabel:IsA("TextButton")) then
		local minSize = textLabel:GetAttribute("MinTextSize") or 10
		local maxSize = textLabel:GetAttribute("MaxTextSize") or 32
		local baseSize = maxSize

		textLabel.TextScaled = false
		textLabel.TextSize = math.clamp(baseSize * scaleFactor, minSize, maxSize)
		textLabel.TextTruncate = Enum.TextTruncate.SplitWord
	end
end

------------------// CONNECTIONS \\------------------

-- Setup hover animations for tagged buttons
for _, element in CS:GetTagged("Animatable") do animateHover(element, 5) end
CS:GetInstanceAddedSignal("Animatable"):Connect(function(element) animateHover(element, 5) end)

---- Play hover sound on buttons
--for _, element in PlayerGui:GetDescendants() do playHoverSound(element) end
--PlayerGui.DescendantAdded:Connect(playHoverSound)

-- Give special gradient effect on tagged UI instances
for _, child in CS:GetTagged("SpecialEffects") do addSpecialEffect(child) end
CS:GetInstanceAddedSignal("SpecialEffects"):Connect(addSpecialEffect)

-- Rotates tagged UI elements continuously
for _, child in CS:GetTagged("SpinUI") do spinUI(child) end
CS:GetInstanceAddedSignal("SpinUI"):Connect(spinUI)

-- Rotates gradients based on attribute speed
for _, gradient in CS:GetTagged("SpinGradient") do spinGradient(gradient) end
CS:GetInstanceAddedSignal("SpinGradient"):Connect(spinGradient)

-- Adjusts text size based on screen resolution for tagged UI text labels
for _, textLabel in CS:GetTagged("ResponsiveText") do setupResponsiveText(textLabel) end
CS:GetInstanceAddedSignal("ResponsiveText"):Connect(setupResponsiveText)
Scythe.connect(tr, workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), function()
	for _, textLabel in CS:GetTagged("ResponsiveText") do
		setupResponsiveText(textLabel)
	end
end)

checkForRipple()

------------------// FUNCTIONS \\--------------------

-- What it does: Chains multiple animation steps in sequence (* = required)
--- steps* : array of steps to run in order
---   {fn, args} : runs a function with given args and waits for it to finish
---   {wait} : waits for a given number of seconds
---   {parallel} : makes the previous function step not block the next step
--- options : table of optional settings
---   parallel : if true, the entire sequence runs without blocking the caller
---   onComplete : callback fired when all steps are done
function UIAnimator.Sequence(steps: {{[string]: any}}, options: {
	parallel: boolean?,
	onComplete: (() -> ())?
	}?)
	
	local function run()
		local i = 1
		while i <= #steps do
			local step = steps[i]

			if step.wait then
				task.wait(step.wait)
				i += 1

			-- Check if next step is {parallel}
			elseif step.fn then
				local nextStep = steps[i + 1]
				local isParallel = nextStep and nextStep.parallel == true

				if isParallel then
					task.spawn(step.fn, table.unpack(step.args or {}))
					i += 2 -- skip the {parallel} step
				else
					step.fn(table.unpack(step.args or {}))
					i += 1
				end

			-- Orphaned parallel with no preceding fn, just skip
			elseif step.parallel then
				i += 1

			else
				i += 1
			end
		end

		if options and options.onComplete then
			options.onComplete()
		end
	end

	if options and options.parallel then
		task.spawn(run)
	else
		run()
	end
end

-- What it does: Fades and slides element with a runoff effect (* = required)
--- element* : pass any UI object
--- show* : a boolean, where TRUE shows the frame and FALSE hides the frame
--- speed : how fast to play the animation
--- blurEnabled : decides if the background should get blurry (also zooms in camera)
--- hideOtherUi : hides other UI elements such as buttons, frames, etc IF they are tagged with "HideableUI"
--- runOffAtEnd : for how long the element keeps sliding off
--- customStartPosition : a custom UDim2 to define a starting position before animation starts
--- customEndPosition : a custom UDim2 to define a ending position after animation is over
--- customTweenInfo : a custom tween info to be passed if needed (NOTE: Overrides 'speed' parameter if it was passed)
function UIAnimator.FadeSlideRunoff(element: GuiObject, speed: number?, blurEnabled: boolean?, hideOtherUi: boolean?, runOffAtEnd: number?, customStartPosition: UDim2?, customEndPosition: UDim2?, customTweenInfo: TweenInfo?)
	element.Visible = false

	local args = resolveAnimArgs(element, speed, blurEnabled, hideOtherUi)
	local runOffDuration = runOffAtEnd or 0.5
	local startPos = customStartPosition or UDim2.new(0.5, 0, 0.6, 0)
	local endPos = customEndPosition or UDim2.new(0.5, 0, 0.5, 0)
	local moveInfo = customTweenInfo or TweenInfo.new(args.speed, Enum.EasingStyle.Linear)

	local diffY = endPos.Y.Scale - startPos.Y.Scale
	local runOffPos = UDim2.new(endPos.X.Scale, endPos.X.Offset, endPos.Y.Scale + (diffY * 0.5), endPos.Y.Offset)

	element.Position = startPos
	element.Visible = true
	applyEntryEffects(args)

	UIAnimator.Fade(element, true, args.speed)
	local entryTween = TS:Create(element, moveInfo, {Position = endPos})
	entryTween:Play()
	entryTween.Completed:Wait()

	local exitInfo = TweenInfo.new(runOffDuration, Enum.EasingStyle.Linear)
	UIAnimator.Fade(element, false, nil, nil, nil, exitInfo)

	local runOffTween = TS:Create(element, exitInfo, {Position = runOffPos})
	runOffTween:Play()
	runOffTween.Completed:Wait()

	element.Visible = false
	applyExitEffects(args)
end

-- What it does: Slides frame in or out (* = required)
--- element* : pass any UI object
--- show* : a boolean, where TRUE shows the frame and FALSE hides the frame
--- speed : how fast to play the animation
--- fadeIn : a boolean to decide whether the elements will fade in as the tween plays
--- blurEnabled : decides if the background should get blurry (also zooms in camera)
--- hideOtherUi : hides other UI elements such as buttons, frames, etc IF they are tagged with "HideableUI"
--- resetOgPos : a boolean to decide whether to put the passed element's position back
--- customStartPosition : a custom UDim2 to define a starting position before animation starts
--- customEndPosition : a custom UDim2 to define a ending position after animation is over
--- customTweenInfo : a custom tween info to be passed if needed (NOTE: Overrides 'speed' parameter if it was passed)
function UIAnimator.FrameSlide(element: GuiObject, show: boolean, speed: number?, fadeIn: boolean?, blurEnabled: boolean?, hideOtherUi: boolean?, resetOgPos: boolean?, customStartPosition: UDim2?, customEndPosition: UDim2?, customTweenInfo: TweenInfo?)
	local args = resolveAnimArgs(element, speed, blurEnabled, hideOtherUi)
	local startPosition = customStartPosition or element:GetAttribute("CustomStartPos") or UDim2.new(0.5, 0, 1.5, 0)
	local endPosition = customEndPosition or element:GetAttribute("CustomEndPos") or UDim2.new(0.5, 0, 0.5, 0)
	local info = customTweenInfo or TweenInfo.new(args.speed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	if show then
		element.Position = startPosition
		element.Visible = true
		applyEntryEffects(args)
		if fadeIn then applyFadeToElement(element, info, true) end

		local tween = TS:Create(element, info, {Position = endPosition})
		tween:Play()
		tween.Completed:Wait()
	else
		local ogPos = element.Position
		applyExitEffects(args)

		local tween = TS:Create(element, info, {Position = startPosition})
		tween:Play()
		tween.Completed:Wait()

		element.Visible = false
		if resetOgPos then element.Position = ogPos end
	end
end

-- What it does: Zooms frame in or out (* = required)
--- element* : pass any UI object
--- show* : a boolean, where TRUE shows the frame and FALSE hides the frame
--- speed : how fast to play the animation
--- blurEnabled : decides if the background should get blurry (also zooms in camera)
--- hideOtherUi : hides other UI elements such as buttons, frames, etc IF they are tagged with "HideableUI"
--- startSize : a custom UDim2 to define a starting size before animation starts
--- customEndPosition : a custom UDim2 to define a ending position after animation is over
function UIAnimator.FrameZoom(element: GuiObject, show: boolean, speed: number?, blurEnabled: boolean?, hideOtherUi: boolean?, startSize: UDim2?, customEndPosition: UDim2?)
	local args = resolveAnimArgs(element, speed, blurEnabled, hideOtherUi)
	local ogSize = element:GetAttribute("OriginalSize") or element.Size

	if show then
		element:SetAttribute("OriginalSize", ogSize)
		element.Size = startSize or element:GetAttribute("CustomStartSize") or UDim2.new(0, 0, 0, 0)
		element.Position = customEndPosition or UDim2.new(0.5, 0, 0.5, 0)
		element.AnchorPoint = Vector2.new(0.5, 0.5)
		element.Visible = true
		applyEntryEffects(args)

		local tween = TS:Create(element, TweenInfo.new(args.speed, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = ogSize})
		tween:Play()
		tween.Completed:Wait()
	else
		local finalSize = element:GetAttribute("CustomEndSize") or UDim2.new(0, 0, 0, 0)
		applyExitEffects(args)

		local tween = TS:Create(element, TweenInfo.new(args.speed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = finalSize})
		tween:Play()
		tween.Completed:Wait()

		element.Visible = false
		element.Size = ogSize
	end
end

-- What it does: Fades in the passed element and all its descendants (* = required)
--- element* : pass any UI object
--- show* : a boolean, where TRUE shows the frame and FALSE hides the frame
--- speed : how fast to fade in
--- blurEnabled : decides if the background should get blurry (also zooms in camera)
--- hideOtherUi : hides other UI elements such as buttons, frames, etc IF they are tagged with "HideableUI"
--- customTweenInfo : a custom tween info to be passed if needed (NOTE: Overrides 'speed' parameter if it was passed)
function UIAnimator.Fade(element: GuiObject, show: boolean, speed: number?, blurEnabled: boolean?, hideOtherUi: boolean?, customTweenInfo: TweenInfo?)
	local args = resolveAnimArgs(element, speed, blurEnabled, hideOtherUi)
	local tweenInfo = customTweenInfo or TweenInfo.new(0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

	if show then
		if element:IsA("GuiObject") then element.Visible = true end
		applyEntryEffects(args)
	else
		applyExitEffects(args)
	end

	applyFadeToElement(element, tweenInfo, show)

	if not show then
		task.delay(tweenInfo.Time, function()
			if element:IsA("GuiObject") then element.Visible = false end
		end)
	end
end

-- What it does: Quickly bounces element size up and down (* = required)
--- element* : pass any UI object
--- speed : how fast to bounce in and out
--- bouncePercent : how much to bounce
function UIAnimator.FrameBounce(element: GuiObject, speed: number?, bouncePercent: number?)
	local ogSize = element:GetAttribute("OriginalSize") or element.Size
	if not element:GetAttribute("OriginalSize") then
		element:SetAttribute("OriginalSize", ogSize)
	end
	local percent = bouncePercent or 35
	local animSpeed = speed or 0.7

	local scaleFactor = 1 + (percent * 0.01)
	local largerSize = UDim2.new(
		ogSize.X.Scale * scaleFactor, ogSize.X.Offset,
		ogSize.Y.Scale * scaleFactor, ogSize.Y.Offset
	)

	local tweenIn = TS:Create(element, TweenInfo.new(animSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = largerSize})
	tweenIn:Play()
	tweenIn.Completed:Wait()

	local tweenOut = TS:Create(element, TweenInfo.new(animSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = ogSize})
	tweenOut:Play()
	tweenOut.Completed:Wait()
end

-- What it does: Plays a text effect on individual characters inside a container (* = required)
--- container* : Frame that acts as the layout boundary
--- label* : TextLabel that defines font, size, color and play area
--- text : optional string to display, falls back to label.Text if not provided
--- options : table of optional settings
---   effect : which text effect to use, default "Typewriter"
---   interval : time between each character appearing, default 0.05
---   speed : duration of each character's entry animation (Jitter = jitter step rate, PlopIn = slide duration, ZoomIn = scale-in duration)
---   intensity : magnitude of the effect (Jitter = pixel shift range, PlopIn = pixels above spawn point, ZoomIn = starting scale)
---   onComplete : callback fired when all characters have appeared
function UIAnimator.ShowText(container: Frame, label: TextLabel, text: string?, options: ShowTextOptions?)
	local finalText = text or label.Text
	local effect = options and options.effect or "Typewriter"
	local onComplete = options and options.onComplete or nil

	local boundX = label.AbsoluteSize.X > 0 and label.AbsoluteSize.X or container.AbsoluteSize.X
	local boundY = label.AbsoluteSize.Y > 0 and label.AbsoluteSize.Y or container.AbsoluteSize.Y

	-- Dynamically calculate TextSize if TextScaled is enabled
	if label.TextScaled then
		local dummy = label:Clone()
		dummy.Visible = false
		dummy.TextScaled = false
		dummy.TextWrapped = true
		dummy.Size = UDim2.new(0, boundX, 0, 10000)
		dummy.Text = finalText
		dummy.Parent = container

		local minSize, maxSize = 1, 100
		local bestSize = 100

		while minSize <= maxSize do
			local midSize = math.floor((minSize + maxSize) / 2)
			dummy.TextSize = midSize

			if dummy.TextBounds.Y <= boundY then
				bestSize = midSize
				minSize = midSize + 1
			else
				maxSize = midSize - 1
			end
		end

		label.TextSize = bestSize
		dummy:Destroy()
	end

	-- Clear existing character labels
	for _, child in container:GetChildren() do
		if child:IsA("TextLabel") and child:GetAttribute("CharLabel") then
			child:Destroy()
		end
	end

	-- Clean up previous trove
	local previous = textScopes[container]
	if previous then Scythe.destroy(previous) end

	label.Visible = false
	local textScope = Scythe.scope()
	textScopes[container] = textScope
	container:SetAttribute("ShowTextActive", true)
	Scythe.add(textScope, function()
		if textScopes[container] == textScope then
			textScopes[container] = nil
			container:SetAttribute("ShowTextActive", false)
		end
	end)

	-- Cleanup on destroy or hide
	Scythe.connect(textScope, container.Destroying, function()
		Scythe.destroy(textScope)
	end)
	Scythe.connect(textScope, label:GetPropertyChangedSignal("Visible"), function()
		if not label.Visible then
			for _, child in container:GetChildren() do
				if child:IsA("TextLabel") and child:GetAttribute("CharLabel") then
					child:Destroy()
				end
			end
			Scythe.destroy(textScope)
		end
	end)

	local preset = require(TextPresets:FindFirstChild(effect))
	if not Scythe.isAlive(textScope) then return end
	local lineHeight = label.TextSize ~= 0 and label.TextSize or label.LineHeight

	preset(container, label, finalText, lineHeight, boundX, textScope, options or {})
	if onComplete and Scythe.isAlive(textScope) then onComplete() end
end

-- What it does: Sets custom camera properties when a frame opens (* = required)
--- props : a table with camera's properties
-- Default is just a camera zoom where the FOV is set to 60
function UIAnimator.SetCameraProps(props: CameraProps?)
	cameraProps = props
end

-- What it does: Sets the strength of the blur effect when a frame opens (* = required)
--- size : the blur strength, default is 15
function UIAnimator.SetBlurSize(size: number?)
	blurSize = size
end

-- What it does: Overrides hover and press preset on a button at runtime (* = required)
--- element* : the button to apply the style to
--- options : table with HoverType, PressType, and optional ScalePercent
function UIAnimator.SetButtonStyle(element: GuiObject, options: {
	hoverType: ("Lift" | "Bounce" | "Grow")?,
	pressType: ("Shrink" | "Punch")?,
	scalePercent: number?
	})
	
	element:SetAttribute("HoverType", options.hoverType or "Grow")
	element:SetAttribute("PressType", options.pressType or "Shrink")
	element:SetAttribute("ScalePercent", options.scalePercent or 5)
	element:SetAttribute("HoverConnected", nil) -- reset so animateHover re-runs
	animateHover(element)
end

-- Stores icon references for specific frames
function UIAnimator.RegisterIcon(icon, frameName: string)
	IconRegistry[frameName] = icon
end

return UIAnimator