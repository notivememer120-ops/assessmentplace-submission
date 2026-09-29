--!strict
local players = game:GetService("Players")
local rep = game:GetService("ReplicatedStorage")
local ts = game:GetService("TweenService")
local guiServ = game:GetService("GuiService")
local uis = game:GetService("UserInputService")
local starterGui = game:GetService("StarterGui")

local config = require(rep.Modules.Configs.DeathUIConfig)
local RespawnPackets = require(rep.Modules.Packets.RespawnPackets).packets
local WaitFor = require(rep.Modules.Gameplay.WaitFor)
local UILib = require(rep.Modules.Gameplay.UILib)
local ModalGuard = require(rep.Modules.Gameplay.ModalGuard)
local Observers = require(rep.Modules.Imported.Backend.Observers)
local Promise = require(rep.Modules.Imported.Backend.Promise)
local Scythe = require(rep.Modules.Imported.Utility.Scythe)
local spr = require(rep.Modules.Imported.Backend.spr)

local player = players.LocalPlayer :: Player

type Controller = {
	__slittttName: string,
	Dependencies: {string},
	_scope: Scythe.Scope,
	_motion: Scythe.Scope,
	_dead: boolean,
	_deathCause: string?,
	_navigation: boolean?,
	_char: Model?,
	_hum: Humanoid?,
	_root: typeof(game.StarterGui.DeathUI.DeathFrame),
	_main: typeof(game.StarterGui.DeathUI.DeathFrame.MainFrame),
	_return: typeof(game.StarterGui.DeathUI.DeathFrame.ReturnWrap),
	_button: typeof(game.StarterGui.DeathUI.DeathFrame.ReturnWrap.Button),
	_label: TextLabel,
	_message: TextLabel,
	_scale: UIScale,
	_saved: {[Instance]: {[string]: number}},
	_reset: BindableEvent,
	_resetBound: boolean?,
	Get: ((Controller, "AutoScaleController") -> typeof(require(script.Parent.AutoScaleController)))
		& ((Controller, "ReportController") -> typeof(require(script.Parent.ReportController)))
		& ((Controller, "CampMenuController") -> typeof(require(script.Parent.CampMenuController))),
	_layout: (Controller) -> (),
	_buttonState: (Controller) -> (),
	_fade: (Controller, boolean, number) -> (),
	_show: (Controller) -> (),
	_hide: (Controller) -> (),
	_bindReset: (Controller) -> Promise.Promise,
	Init: (Controller) -> Promise.Promise,
	Destroy: (Controller) -> (),
}

local DeathController = {} :: Controller
DeathController.__slittttName = "DeathController"
DeathController.Dependencies = {"AutoScaleController", "ReportController", "CampMenuController"}

function DeathController:_layout()
	local safe = guiServ:GetInsetArea(Enum.ScreenInsets.CoreUISafeInsets)
	local available = Vector2.new(math.max(1, safe.Width - 32), math.max(1, safe.Height - 24 - config.buttonSize.Y - config.gap))
	local factor = self:Get("AutoScaleController"):fit(config.panelSize, available)
	local size = config.panelSize * factor
	local center = (safe.Min + safe.Max) / 2 - self._root.AbsolutePosition

	self._main.Size = UDim2.fromOffset(size.X, size.Y)
	self._main.Position = UDim2.fromOffset(center.X, center.Y - (config.buttonSize.Y + config.gap) / 2)
	self._return.Size = UDim2.fromOffset(math.min(config.buttonSize.X, available.X), config.buttonSize.Y)
	self._return.Position = UDim2.fromOffset(center.X, center.Y + (size.Y + config.gap) / 2)
end

function DeathController:_buttonState()
	local pending = player:GetAttribute("Respawning") == true
	local failed = player:GetAttribute("RespawnFailed") == true
	local message = if self._deathCause then config.messages[self._deathCause] or config.message else config.message

	self._button.Interactable = self._dead and not pending
	self._button.Selectable = self._button.Interactable
	self._label.Text = if pending then config.respawning else if failed then config.retry else config.respawn
	self._message.Text = if failed then config.failed else message
end

function DeathController:_fade(show, duration)
	for inst, props in self._saved do
		local target = {}

		for name, value in props do
			target[name] = if show then value else 1
		end

		Scythe.add(self._motion, ts:Create(inst, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), target), "Cancel"):Play()
	end
end

function DeathController:_show()
	if self._dead then
		return
	end

	self._dead = true
	self._deathCause = player:GetAttribute(config.causeAttribute) :: string?

	if not self._deathCause and self._hum then
		self._deathCause = self._hum:GetAttribute(config.causeAttribute) :: string?
	end

	self._navigation = guiServ.GuiNavigationEnabled
	guiServ.GuiNavigationEnabled = true

	self:Get("ReportController"):Close()
	self:Get("CampMenuController"):Close()

	Scythe.clean(self._motion)

	self:_layout()

	self._root.Visible = true
	self._root.Dim.Active = true
	self._scale.Scale = 0.9

	spr.target(self._scale, 0.8, 5, {Scale = 1})
	Scythe.add(self._motion, function()
		spr.stop(self._scale)
	end)

	self:_fade(true, config.revealTime)
	self:_buttonState()

	if uis.PreferredInput == Enum.PreferredInput.Gamepad then
		guiServ.SelectedObject = self._button
	end
end

function DeathController:_hide()
	if self._navigation ~= nil then
		guiServ.GuiNavigationEnabled = self._navigation
		self._navigation = nil
	end

	self._dead = false

	Scythe.clean(self._motion)

	self:_buttonState()

	if not self._root.Visible then
		return
	end

	self:_fade(false, config.hideTime)

	Scythe.add(self._motion, task.delay(config.hideTime, function()
		self._root.Visible = false
		self._root.Dim.Active = false
	end))

	if guiServ.SelectedObject == self._button then
		guiServ.SelectedObject = nil
	end
end

function DeathController:_bindReset()
	self._reset = Scythe.add(self._scope, Instance.new("BindableEvent"))

	Scythe.connect(self._scope, self._reset.Event, function()
		RespawnPackets.Reset.send()
	end)

	return Scythe.addPromise(self._scope, Promise.retryWithDelay(function()
		return Promise.try(function()
			starterGui:SetCore("ResetButtonCallback", self._reset)

			self._resetBound = true
		end)
	end, 10, 0.25))
end

function DeathController:Init()
	self._scope = Scythe.scope()
	self._motion = Scythe.extend(self._scope)
	self._dead = false

	local gui = WaitFor:get(player.PlayerGui, "DeathUI") :: typeof(game.StarterGui.DeathUI)
	gui.Enabled = true

	self._root = WaitFor:get(gui, "DeathFrame") :: typeof(game.StarterGui.DeathUI.DeathFrame)
	self._main = self._root.MainFrame
	self._scale = self._main.MotionScale
	self._return = self._root.ReturnWrap
	self._button = self._return.Button
	self._label = self._button.Label

	local content = self._main.Holder.Content
	content.Title.Text = config.title
	content.TitleShadow.Text = config.title
	content.KeyLine.Visible = false
	content.UserLine.Visible = false
	content.TailLine.Visible = false

	self._message = content.LeadLine
	self._message.Text = config.message

	self._saved = UILib.saveTransparencies(self._root)

	for _, v in self._root:GetDescendants() do
		if v:IsA("UIStroke") then
			self._saved[v] = {Transparency = v.Transparency}
		end
	end

	for inst, props in self._saved do
		local object = inst :: Instance & {[string]: number}

		for name in props do
			object[name] = 1
		end
	end

	self._root.Visible = false
	self._root.Dim.Active = false

	ModalGuard.register(self._root)

	Scythe.connect(self._scope, self._button.Activated, function()
		if self._dead and player:GetAttribute("Respawning") ~= true then
			RespawnPackets.Request.send()
		end
	end)

	Scythe.connect(self._scope, self._root:GetPropertyChangedSignal("AbsoluteSize"), function()
		self:_layout()
	end)

	Scythe.connect(self._scope, player:GetAttributeChangedSignal("Respawning"), function()
		self:_buttonState()
	end)

	Scythe.connect(self._scope, player:GetAttributeChangedSignal("RespawnFailed"), function()
		if player:GetAttribute("RespawnFailed") and not player.Character then
			self:_show()
		end

		self:_buttonState()
	end)

	Scythe.connect(self._scope, player:GetAttributeChangedSignal(config.deadAttribute), function()
		if player:GetAttribute(config.deadAttribute) then
			self:_show()
		else
			self:_hide()
		end
	end)

	Scythe.connect(self._scope, player:GetAttributeChangedSignal(config.causeAttribute), function()
		if self._dead then
			self._deathCause = player:GetAttribute(config.causeAttribute) :: string?

			self:_buttonState()
		end
	end)

	Scythe.add(self._scope, Observers.observeLocalCharacter(function(char)
		self._char = char
		self._hum = nil

		if player:GetAttribute(config.deadAttribute) then
			self:_show()
		else
			self._deathCause = nil

			self:_hide()
		end

		local scope = Scythe.scope()

		Scythe.add(scope, task.defer(function()
			local hum = WaitFor:get(char, "Humanoid", 10) :: Humanoid

			if player.Character ~= char then
				return
			end

			self._hum = hum

			Scythe.connect(scope, hum:GetAttributeChangedSignal(config.causeAttribute), function()
				if self._char == char and self._dead then
					self._deathCause = hum:GetAttribute(config.causeAttribute) :: string?

					self:_buttonState()
				end
			end)

			Scythe.connect(scope, hum.Died, function()
				if self._char == char then
					self:_show()
				end
			end)

			Scythe.connect(scope, hum.HealthChanged, function(health)
				if self._char == char and health <= 0 then
					self:_show()
				end
			end)

			if hum.Health <= 0 then
				self:_show()
			end
		end))

		return function()
			Scythe.destroy(scope)
		end
	end))

	self:_layout()
	self:_buttonState()

	if player:GetAttribute(config.deadAttribute) then
		self:_show()
	end

	return self:_bindReset()
end

function DeathController:Destroy()
	if self._navigation ~= nil then
		guiServ.GuiNavigationEnabled = self._navigation
	end

	Scythe.destroy(self._scope)

	if self._resetBound then
		starterGui:SetCore("ResetButtonCallback", true)

		self._resetBound = false
	end

	spr.stop(self._scale)

	self._root.Visible = false
	self._root.Dim.Active = false
end

return DeathController