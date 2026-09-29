--!strict
local players = game:GetService("Players")
local rep = game:GetService("ReplicatedStorage")
local ts = game:GetService("TweenService")

local config = require(rep.Modules.Configs.DamageUIConfig)
local features = require(rep.Modules.Configs.GameConfig).features
local WaitFor = require(rep.Modules.Gameplay.WaitFor)
local Observers = require(rep.Modules.Imported.Backend.Observers)
local Scythe = require(rep.Modules.Imported.Utility.Scythe)
local spr = require(rep.Modules.Imported.Backend.spr)

local player = players.LocalPlayer :: Player
local DamageVignetteController = {}
DamageVignetteController.__slittttName = "DamageVignetteController"

type Controller = typeof(DamageVignetteController) & {
	_scope: Scythe.Scope,
	_flashScope: Scythe.Scope,
	_wound: ImageLabel,
	_flash: ImageLabel,
	_ambient: ImageLabel,
	_char: Model?,
}

function DamageVignetteController._reset(self: Controller)
	Scythe.clean(self._flashScope)
	spr.stop(self._wound)

	self._wound.ImageTransparency = 1
	self._flash.ImageTransparency = 1
end

function DamageVignetteController._update(self: Controller, hum: Humanoid)
	local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
	local transparency = 1

	if ratio < config.criticalRatio then
		transparency = config.minimumTransparency + ratio / config.criticalRatio * (config.criticalTransparency - config.minimumTransparency)
	elseif ratio < config.healthyRatio then
		transparency = config.criticalTransparency + (ratio - config.criticalRatio) / (config.healthyRatio - config.criticalRatio) * (1 - config.criticalTransparency)
	end

	spr.target(self._wound, 1, 6, {ImageTransparency = transparency})
end

function DamageVignetteController.Init(self: Controller)
	self._scope = Scythe.scope()
	self._flashScope = Scythe.extend(self._scope)

	local gui = WaitFor:get(player.PlayerGui, "DamageVignette") :: ScreenGui

	self._wound = WaitFor:get(gui, "Vignette") :: ImageLabel
	self._flash = WaitFor:get(gui, "GotDamage") :: ImageLabel
	self._ambient = WaitFor:chain(player.PlayerGui, {"Vignette", "Vignette"}) :: ImageLabel
	gui.Enabled = true
	(self._ambient.Parent :: ScreenGui).Enabled = features.ambientVignette

	for _, v in {self._wound, self._flash, self._ambient} do
		v.Visible = true
		v.Active = false
	end

	self._wound.ImageColor3 = config.woundColor
	self._flash.ImageColor3 = config.flashColor

	self:_reset()

	Scythe.add(self._scope, Observers.observeLocalCharacter(function(char)
		self._char = char

		self:_reset()

		local scope = Scythe.scope()

		Scythe.add(scope, task.defer(function()
			local hum = WaitFor:get(char, "Humanoid", 10) :: Humanoid

			if player.Character ~= char then return end

			local lastHealth = hum.Health

			self:_update(hum)

			Scythe.connect(scope, hum.HealthChanged, function(health)
				if self._char ~= char then return end

				if health < lastHealth then
					Scythe.clean(self._flashScope)

					self._flash.ImageTransparency = 0

					Scythe.add(self._flashScope, ts:Create(self._flash, config.flashTweenInfo, {ImageTransparency = 1}), "Cancel"):Play()
				end

				lastHealth = health

				self:_update(hum)
			end)

			Scythe.connect(scope, hum:GetPropertyChangedSignal("MaxHealth"), function()
				if self._char == char then self:_update(hum) end
			end)
		end))

		return function()
			Scythe.destroy(scope)

			if self._char == char then
				self._char = nil

				self:_reset()
			end
		end
	end))
end

function DamageVignetteController.Destroy(self: Controller)
	self:_reset()

	Scythe.destroy(self._scope)

	self._ambient.Visible = false
end

return DamageVignetteController