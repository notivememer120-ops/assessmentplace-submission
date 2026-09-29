--!strict
local rotAmp = math.rad(0.4)
local posAmp = 0.1
local noiseHz = 12

local ScreenShake = {}
local active = {}

local rumble = Instance.new("HapticEffect")
rumble.Type = Enum.HapticEffectType.Custom
rumble.Looped = true
rumble:SetWaveformKeys({
	FloatCurveKey.new(0, 0.5, Enum.KeyInterpolationMode.Linear),
	FloatCurveKey.new(200, 0.5, Enum.KeyInterpolationMode.Linear),
})
rumble.Parent = workspace

function ScreenShake.start(intensity)
	local handle = {intensity = intensity or 1}

	if not next(active) then
		rumble:Play()
	end

	active[handle] = true

	return handle
end

function ScreenShake.stop(handle)
	active[handle] = nil

	if not next(active) then
		rumble:Stop()
	end
end

function ScreenShake.currentOffset()
	local mult = 0

	for handle in active do
		mult = math.max(mult, handle.intensity)
	end

	if mult == 0 then
		return CFrame.identity
	end

	local t = os.clock() * noiseHz
	local rx = math.noise(t, 0.7) * 2 * rotAmp * mult
	local ry = math.noise(t, 31.4) * 2 * rotAmp * mult
	local ox = math.noise(t, 77.7) * 2 * posAmp * mult
	local oy = math.noise(t, 113.9) * 2 * posAmp * mult

	return CFrame.Angles(rx, ry, 0) * CFrame.new(ox, oy, 0)
end

return ScreenShake