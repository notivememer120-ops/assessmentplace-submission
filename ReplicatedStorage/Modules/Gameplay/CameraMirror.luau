local flipSeconds = 0.4

local CameraMirror = {}

local target = 0
local fromAmount = 0
local startedAt = 0
local amount = 0

local function sineInOut(p)
	return (1 - math.cos(p * math.pi)) / 2
end

local function compute()
	local p = flipSeconds > 0 and math.clamp((os.clock() - startedAt) / flipSeconds, 0, 1) or 1

	amount = fromAmount + (target - fromAmount) * sineInOut(p)

	return amount
end

function CameraMirror.start()
	compute()

	fromAmount = amount
	target = 1
	startedAt = os.clock()
end

function CameraMirror.stop()
	compute()

	fromAmount = amount
	target = 0
	startedAt = os.clock()
end

function CameraMirror.currentTransform()
	local a = compute()

	if a <= 1e-4 then
		return CFrame.identity
	end

	-- reflect the camera's local right axis: R00 rides 1 -> -1, so the view squishes through
	-- zero width at the midpoint then renders mirrored. post-multiplied, it stays view-relative
	local r00 = 1 - 2 * a
	return CFrame.new(0, 0, 0, r00, 0, 0, 0, 1, 0, 0, 0, 1)
end

return CameraMirror