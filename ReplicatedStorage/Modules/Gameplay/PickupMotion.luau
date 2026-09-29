--!strict
local PickupMotion = {}

function PickupMotion.hover(origin: CFrame, time: number, phase: number, config: {frequency: number, amplitude: number, spinSpeed: number}): CFrame
	local y = (math.sin(time * config.frequency + phase) + 1) * config.amplitude / 2
	return CFrame.new(origin.Position + Vector3.yAxis * y) * CFrame.Angles(0, (time * config.spinSpeed + phase) % (math.pi * 2), 0) * origin.Rotation
end

function PickupMotion.flight(origin: Vector3, target: Vector3, progress: number, height: number): Vector3
	local t = math.clamp(progress, 0, 1)
	return origin:Lerp(target, t) + Vector3.yAxis * (2 * height * t * (1 - t))
end

return PickupMotion