local ts = game:GetService("TweenService")
local uis = game:GetService("UserInputService")

local HoverPop = {}
local defaultInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function scaleOf(target)
	local existing = target:FindFirstChildOfClass("UIScale")
	
	if existing then
		return existing
	end

	local scale = Instance.new("UIScale")
	scale.Parent = target

	return scale
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

function HoverPop.attach(activator, target, opts)
	if not opts then
		opts = {}
	end

	local hover = opts.hover or 1.07
	local press = opts.press or 0.95
	local upright = opts.upright or 0
	local info = opts.info or defaultInfo

	local scale = scaleOf(target)
	local baseScale = scale.Scale
	local baseRot = target.Rotation

	local hovering = false
	local held = false

	local function settle()
		local mult = 1
		local rot = baseRot

		if held then
			mult = press
			rot = upright
		elseif hovering then
			mult = hover
			rot = upright
		end

		ts:Create(scale, info, {Scale = baseScale * mult}):Play()
		ts:Create(target, info, {Rotation = rot}):Play()
	end

	activator.MouseEnter:Connect(function()
		hovering = true
		
		settle()
	end)

	activator.MouseLeave:Connect(function()
		hovering = false
		held = false
		
		settle()
	end)

	activator.InputBegan:Connect(function(input)
		if isPress(input) then
			held = true

			settle()
		end
	end)

	uis.InputEnded:Connect(function(input)
		if held and isPress(input) then
			held = false

			settle()
		end
	end)

	return scale
end

return HoverPop