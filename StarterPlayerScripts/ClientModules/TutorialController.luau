--!strict
local rep = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local uis = game:GetService("UserInputService")
local cas = game:GetService("ContextActionService")

local config = require(rep.Modules.Configs.TutorialConfig)
local WaitFor = require(rep.Modules.Gameplay.WaitFor)
local ScreenPoint = require(rep.Modules.Gameplay.ScreenPoint)
local ModalGuard = require(rep.Modules.Gameplay.ModalGuard)
local LoadingScreenEvents = require(rep.Modules.Gameplay.LoadingScreenEvents)
local Observers = require(rep.Modules.Imported.Backend.Observers)
local Timer = require(rep.Modules.Imported.Backend.Timer)
local Scythe = require(rep.Modules.Imported.Utility.Scythe)
local typewriter = require(rep.Modules.Imported.Utility.UIAnimator.Presets.Text.Typewriter)

local player = players.LocalPlayer :: Player
local TutorialController = {}
TutorialController.__slittttName = "TutorialController"
TutorialController.Dependencies = {"SprintController", "SettingsTopbar"}

type InputMode = "touch" | "gamepad" | "keyboard" | "keyboardHold"

type Controller = typeof(TutorialController) & {
	_scope: Scythe.Scope,
	_messageScope: Scythe.Scope,
	_gui: typeof(game.StarterGui.TutorialUI),
	_panel: typeof(game.StarterGui.TutorialUI.TutorialFrame),
	_hint: TextLabel,
	_stage: ("sprint" | "complete")?,
	_mode: InputMode?,
	_target: GuiButton?,
	_hum: Humanoid?,
	Get: (Controller, "SettingsTopbar") -> typeof(require(script.Parent.SettingsTopbar)),
}

function TutorialController._hide(self: Controller)
	Scythe.clean(self._messageScope)

	self._panel.Visible = false
	self._stage = nil
	self._mode = nil

	ScreenPoint.Clear()
end

function TutorialController._text(self: Controller, text: string)
	Scythe.clean(self._messageScope)

	self._panel.Visible = true

	Scythe.add(self._messageScope, task.defer(typewriter, self._panel, self._hint, text, 0, 0, self._messageScope, {interval = config.characterInterval} :: {interval: number?}))
end

function TutorialController._layout(self: Controller)
	local width = math.min(config.panelSize.X, math.max(1, self._gui.AbsoluteSize.X - 220))

	self._panel.Size = UDim2.fromOffset(width, config.panelSize.Y)
	self._panel.Position = UDim2.new(0.5, 0, 0, 12)
end

function TutorialController._update(self: Controller)
	if not self._hum or self._hum.Health <= 0 or not LoadingScreenEvents.HasHidden or ModalGuard.anyOpen() then
		if self._stage then self:_hide() end

		return
	end

	if player:GetAttribute("TutorialReady") ~= true then return end

	if player:GetAttribute("SprintTutorialCompleted") == true then
		if self._stage == "sprint" then
			self._stage = "complete"

			ScreenPoint.Clear()

			self:_text(config.text.complete)

			Scythe.add(self._messageScope, task.delay(config.completionSeconds, function()
				self._panel.Visible = false
				self._stage = nil
			end))
		end

		return
	end

	local mode: InputMode = if uis.PreferredInput == Enum.PreferredInput.Touch then "touch" else if uis.PreferredInput == Enum.PreferredInput.Gamepad then "gamepad" else if self:Get("SettingsTopbar"):GetValue("sprintToggle") then "keyboard" else "keyboardHold"

	if self._stage ~= "sprint" or self._mode ~= mode then
		self._stage = "sprint"
		self._mode = mode

		self:_text(config.text[mode])

		ScreenPoint.Clear()

		self._target = nil
	end

	if mode == "touch" then
		local button = cas:GetButton("sprint") :: GuiButton?

		if button and button.Visible and button.AbsoluteSize.X > 0 and button ~= self._target then
			self._target = button

			ScreenPoint.Set(button, {arrowOnly = true})
		end
	end
end

function TutorialController.Init(self: Controller)
	self._scope = Scythe.scope()
	self._messageScope = Scythe.extend(self._scope)
	self._gui = WaitFor:get(player.PlayerGui, "TutorialUI") :: typeof(game.StarterGui.TutorialUI)
	self._panel = self._gui.TutorialFrame
	self._hint = self._panel.Hint
	self._gui.Enabled = true
	self._panel.Visible = false

	Scythe.connect(self._scope, self._gui:GetPropertyChangedSignal("AbsoluteSize"), function() self:_layout() end)
	Scythe.add(self._scope, Observers.observeLocalCharacter(function(char)
		self._hum = nil

		self:_hide()

		local scope = Scythe.scope()

		Scythe.add(scope, task.defer(function()
			local hum = WaitFor:get(char, "Humanoid", 10) :: Humanoid

			if player.Character ~= char then return end

			self._hum = hum

			Scythe.connect(scope, hum.Died, function() self:_hide() end)

			self:_update()
		end))

		return function()
			Scythe.destroy(scope)

			if self._hum and self._hum.Parent == char then
				self._hum = nil

				self:_hide()
			end
		end
	end))

	Scythe.add(self._scope, Timer.simple(0.1, function() self:_update() end))

	self:_layout()
end

function TutorialController.Destroy(self: Controller)
	self:_hide()

	Scythe.destroy(self._scope)
end

return TutorialController