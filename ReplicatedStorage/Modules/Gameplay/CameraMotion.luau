--!strict
local rep = game:GetService("ReplicatedStorage")
local Spring = require(rep.Modules.Imported.Utility.Spring)
local config = require(rep.Modules.Configs.GameConfig).camera
local movement = require(rep.Modules.Configs.GameConfig).movement
local footsteps = require(rep.Modules.Configs.FootstepConfig)

local CameraMotion = {}
CameraMotion.__index = CameraMotion

export type Motion = typeof(setmetatable({} :: {
	time: number,
	phase: number,
	fall: number,
	grounded: boolean?,
	quality: Spring.Spring<number>,
	amount: Spring.Spring<number>,
	run: Spring.Spring<number>,
	lean: Spring.Spring<Vector3>,
	landing: Spring.Spring<number>,
}, CameraMotion))

function CameraMotion.new(): Motion
	local self = setmetatable({time = 0, phase = 0, fall = 0}, CameraMotion) :: Motion

	local function clock() return self.time end

	self.quality = Spring.new(1, 1, 10, clock)
	self.amount = Spring.new(0, 1, 14, clock)
	self.run = Spring.new(0, 1, 7, clock)
	self.lean = Spring.new(Vector3.zero, 0.85, 14, clock)
	self.landing = Spring.new(0, 0.65, 18, clock)
	return self
end

function CameraMotion.Reset(self: Motion)
	self.quality:Reset()
	self.amount:Reset()
	self.run:Reset()
	self.lean:Reset()
	self.landing:Reset()

	self.phase = 0
	self.fall = 0
	self.grounded = nil
end

function CameraMotion.Step(self: Motion, dt: number, velocity: Vector3, grounded: boolean, sprinting: boolean?, turn: number, weight: number): (CFrame, number)
	self.quality.Target = math.clamp((1 / math.max(dt, 1 / 240) - 5) / 25, 0, 1)
	dt = math.min(dt, 0.25)

	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local moving = grounded and speed > footsteps.minimumSpeed
	local pace = math.clamp(speed / movement.runSpeed, 0, 1)

	self.amount.Target = if moving then math.min(speed / movement.walkSpeed, 1) else 0
	self.run.Target = if sprinting and moving then pace else 0
	self.lean.Target = Vector3.new(
		0,
		-turn * config.turnYaw,
		(if moving then -math.clamp(velocity.X / movement.runSpeed, -1, 1) * config.strafeRoll else 0) + turn * config.turnRoll
	)

	if grounded then
		if self.grounded == false then
			self.landing:Impulse(-math.clamp(self.fall - 8, 0, 65) * config.landingImpulse)
		end

		self.fall = 0
	else
		self.fall = math.max(self.fall, -velocity.Y)
	end

	self.grounded = grounded
	self.time += dt

	if moving then
		local cadence = math.min(speed / config.stride, config.maxCadence, 1 / (dt * 5))

		self.phase = (self.phase + cadence * dt * math.pi) % (math.pi * 2)
	end

	weight *= config.amplitude * self.quality.Position

	local amount = self.amount.Position
	local run = self.run.Position
	local lean = self.lean.Position
	local landing = math.clamp(self.landing.Position, -0.3, 0.1)
	local stride = math.sin(self.phase)
	local step = math.cos(self.phase * 2)
	local strength = amount * (1 + run * 0.65)
	local breath = if grounded then math.sin(self.time * 1.7) * 0.012 * (1 - amount) else 0
	local offset = Vector3.new(stride * config.sway * strength, step * config.bob * strength + breath + landing, 0) * weight
	local pitch = step * 0.3 * strength + landing * 5
	local roll = stride * config.stepRoll * strength + lean.Z
	return CFrame.new(offset) * CFrame.Angles(math.rad(pitch * weight), math.rad(lean.Y * weight), math.rad(roll * weight)), run * config.sprintFov
end

return CameraMotion