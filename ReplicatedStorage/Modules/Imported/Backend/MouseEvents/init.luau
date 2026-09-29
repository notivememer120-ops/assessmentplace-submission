local Kernel = require(script.Kernel)
local Hover = require(script.Hover)
local Tween = require(script.Tween)

local autoSound = script:FindFirstChildOfClass("Sound")
if autoSound then
	Kernel.useSound(autoSound)
end

return {
	Hover = Hover,
	Tween = Tween,
}