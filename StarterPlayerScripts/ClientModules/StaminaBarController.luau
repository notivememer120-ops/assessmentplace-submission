--!strict
local players = game:GetService("Players")
local rep = game:GetService("ReplicatedStorage")
local ts = game:GetService("TweenService")

local WaitFor = require(rep.Modules.Gameplay.WaitFor)

local player = players.LocalPlayer :: Player

local fillInfo = TweenInfo.new(0.12, Enum.EasingStyle.Linear)
local fadeInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local hideDelay = 0.4
local fillColor = Color3.fromRGB(235, 235, 225)
local lockedColor = Color3.fromRGB(190, 70, 60)

local StaminaBarController = {}
StaminaBarController.__slittttName = "StaminaBarController"
StaminaBarController.Dependencies = {"AutoScaleController"}

type Controller = typeof(StaminaBarController) & {
	_track: typeof(game.StarterGui.Stamina.Track),
	_fill: Frame,
	_hideToken: number,
	Get: (Controller, "AutoScaleController") -> typeof(require(script.Parent.AutoScaleController)),
}

local function stamina(): number
	return (player:GetAttribute("stamina") :: number?) or 1
end

function StaminaBarController._apply(self: Controller)
	local value = stamina()

	ts:Create(self._fill, fillInfo, {Size = UDim2.new(value, 0, 1, 0)}):Play()

	self._fill.BackgroundColor3 = if player:GetAttribute("sprintLocked") then lockedColor else fillColor

	self._hideToken += 1

	if value < 1 then
		ts:Create(self._track, fadeInfo, {GroupTransparency = 0}):Play()
		return
	end

	local token = self._hideToken

	task.delay(hideDelay, function()
		if token == self._hideToken and stamina() >= 1 then
			ts:Create(self._track, fadeInfo, {GroupTransparency = 1}):Play()
		end
	end)
end

function StaminaBarController.Init(self: Controller)
	local gui = WaitFor:get(player.PlayerGui, "Stamina") :: typeof(game.StarterGui.Stamina)

	self:Get("AutoScaleController"):attach(gui)

	self._track = gui.Track
	self._fill = self._track.Fill
	self._hideToken = 0
	self._track.GroupTransparency = 1

	player:GetAttributeChangedSignal("stamina"):Connect(function()
		self:_apply()
	end)

	player:GetAttributeChangedSignal("sprintLocked"):Connect(function()
		self:_apply()
	end)

	self:_apply()
end

return StaminaBarController