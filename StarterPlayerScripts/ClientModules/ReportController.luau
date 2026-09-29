--!strict
local players = game:GetService("Players")
local rep = game:GetService("ReplicatedStorage")
local httpServ = game:GetService("HttpService")
local ts = game:GetService("TweenService")
local uis = game:GetService("UserInputService")
local guiServ = game:GetService("GuiService")
local cas = game:GetService("ContextActionService")

local WaitFor = require(rep.Modules.Gameplay.WaitFor)
local ReportText = require(rep.Modules.Gameplay.ReportText)
local uiConfig = require(rep.Modules.Configs.ReportUIConfig)
local gameConfig = require(rep.Modules.Configs.GameConfig)
local ModalGuard = require(rep.Modules.Gameplay.ModalGuard)
local UISfx = require(rep.Modules.Gameplay.UISfx)
local ReportPackets = require(rep.Modules.Packets.ReportPackets).packets
local Promise = require(rep.Modules.Imported.Backend.Promise)
local Timer = require(rep.Modules.Imported.Backend.Timer)
local Scythe = require(rep.Modules.Imported.Utility.Scythe)
local spr = require(rep.Modules.Imported.Backend.spr)
local detectPlatform = require(rep.Modules.Imported.Utility.OSDetector)

local player = players.LocalPlayer :: Player
local muted = Color3.fromHex("bdc7c7")

type Result = {requestId: string, ok: boolean, reason: string, remaining: number, cooldown: number}

type Controller = {
	__slittttName: string,
	Dependencies: {string},
	_root: typeof(game.StarterGui.Tabs.Report),
	_opener: typeof(game.StarterGui.Tabs.ReportButton),
	_wrap: typeof(game.StarterGui.Tabs.Report.FadeWrap),
	_dlg: typeof(game.StarterGui.Tabs.Report.FadeWrap.Dlg),
	_card: typeof(game.StarterGui.Tabs.Report.FadeWrap.Dlg.Card),
	_form: typeof(game.StarterGui.Tabs.Report.FadeWrap.Dlg.Card.Form),
	_status: typeof(game.StarterGui.Tabs.Report.FadeWrap.Dlg.Card.Status),
	_input: TextBox,
	_send: typeof(game.StarterGui.Tabs.Report.FadeWrap.Dlg.Card.Form.Send),
	_scrim: TextButton,
	_scale: UIScale,
	_minimum: number,
	_maximum: number,
	_responseTimeout: number,
	_failurePenalty: number,
	_scope: Scythe.Scope,
	_motion: Scythe.Scope,
	_requestScope: Scythe.Scope,
	_modalScope: Scythe.Scope,
	_pointers: {[InputObject]: boolean},
	_open: boolean,
	_pending: boolean,
	_success: boolean,
	_active: boolean,
	_cooldownUntil: number,
	_retryAt: number,
	_device: string,
	_layoutQueued: boolean?,
	_keyboardLayout: boolean?,
	_typingLayout: boolean,
	_error: string?,
	_request: string?,
	_submittedText: string,
	Get: ((Controller, "AutoScaleController") -> typeof(require(script.Parent.AutoScaleController)))
		& ((Controller, "InteractFXController") -> typeof(require(script.Parent.InteractFXController)))
		& ((Controller, "SprintController") -> typeof(require(script.Parent.SprintController))),
	_queueLayout: (Controller) -> (),
	_layout: (Controller) -> (),
	_render: (Controller) -> (),
	Open: (Controller) -> (),
	Close: (Controller) -> (),
	Submit: (Controller) -> (),
	_result: (Controller, Result) -> (),
	Init: (Controller) -> (),
	Destroy: (Controller) -> (),
}

local ReportController = {} :: Controller
ReportController.__slittttName = "ReportController"
ReportController.Dependencies = {"InteractFXController", "AutoScaleController", "SprintController"}

function ReportController:_queueLayout()
	if self._layoutQueued then
		return
	end

	self._layoutQueued = true

	task.defer(function()
		self._layoutQueued = false

		if self._active then
			self:_layout()
		end
	end)
end

function ReportController:_layout()
	if next(self._pointers) and self._keyboardLayout then
		return
	end

	local size = self._root.AbsoluteSize
	local height = size.Y
	local full = guiServ:GetInsetArea(Enum.ScreenInsets.None)

	self._scrim.Position = UDim2.fromOffset(full.Min.X - self._root.AbsolutePosition.X, full.Min.Y - self._root.AbsolutePosition.Y)
	self._scrim.Size = UDim2.fromOffset(full.Width, full.Height)

	self._keyboardLayout = uis.OnScreenKeyboardVisible and self._input:IsFocused()

	if self._keyboardLayout then
		local inset = guiServ:GetGuiInset()

		height = math.min(height, uis.OnScreenKeyboardPosition.Y - inset.Y - self._root.AbsolutePosition.Y)
	end

	local available = Vector2.new(math.max(1, size.X - 24), math.max(1, height - 16))
	local compact = available.Y < 440

	self._typingLayout = available.Y < 240

	local width = math.min(available.X, if compact then 576 else 448)
	local design = Vector2.new(width, if self._typingLayout then 128 else if compact then 292 else 512)

	self._wrap.Size = UDim2.fromOffset(design.X, design.Y)
	self._wrap.Position = UDim2.new(0.5, 0, 0, height / 2)
	self._wrap.FitScale.Scale = self:Get("AutoScaleController"):fit(design, available)

	local top = if self._typingLayout then 16 else if compact then 88 else 165

	self._card.Header.Visible = not self._typingLayout
	self._card.Header.Size = UDim2.new(1, 0, 0, if compact then 72 else 140)
	self._card.Header.Subtitle.Visible = not compact
	self._card.Header.Eyebrow.Visible = not compact
	self._card.Header.Bug.Visible = not compact
	self._card.Header.Title.Position = UDim2.fromOffset(26, if compact then 16 else 58)
	self._card.Header.Title.Size = UDim2.new(1, if compact then -94 else -52, 0, 42)
	self._form.Position = UDim2.fromOffset(26, top)
	self._form.Size = UDim2.new(1, -52, 1, -top - 24)
	self._status.Position = self._form.Position
	self._status.Size = self._form.Size
	self._status.Badge.Visible = not compact
	self._status.Message.Position = UDim2.fromOffset(0, if compact then 0 else 90)
	self._status.Message.Size = UDim2.new(1, 0, 0, if compact then 44 else 54)
	self._form.InputFrame.Position = UDim2.fromOffset(0, if self._typingLayout then 0 else 30)
	self._form.InputFrame.Size = if self._typingLayout then UDim2.new(1, -84, 1, 0) else UDim2.new(1, 0, 1, if compact then -112 else -160)
	self._form.Prompt.Visible = not self._typingLayout
	self._form.Count.Visible = not self._typingLayout
	self._form.Help.Visible = not self._typingLayout
	self._form.Help.Position = UDim2.new(0, 0, 1, if compact then -76 else -121)
	self._form.Help.Size = UDim2.new(1, 0, 0, if compact then 24 else 34)
	self._send.Position = if self._typingLayout then UDim2.new(1, -72, 1, -44) else UDim2.new(0, 0, 1, if compact then -46 else -80)
	self._send.Size = if self._typingLayout then UDim2.fromOffset(72, 44) else UDim2.new(1, 0, 0, 46)
	self._send.Face.Label.Position = UDim2.fromOffset(if self._typingLayout then 4 else 14, 0)
	self._send.Face.Label.Size = UDim2.new(1, if self._typingLayout then -8 else -28, 1, 0)
	self._send.Face.Label.TextSize = if self._typingLayout then 13 else 17
	self._form.Footer.Visible = not compact
	self._status.Done.Position = UDim2.new(0, 0, 1, if compact then -46 else -72)
	self._status.Done.Size = UDim2.new(1, 0, 0, 46)
	self._status.Countdown.Position = UDim2.new(0, 0, 1, if compact then -88 else -112)
	self._input.Size = UDim2.new(1, -28, 0, math.max(40, self._form.InputFrame.AbsoluteSize.Y - 24))

	if uis.TouchEnabled then
		self._opener.AnchorPoint = Vector2.new(1, 0)
		self._opener.Position = UDim2.new(1, -12, 0, 12)
	else
		self._opener.AnchorPoint = Vector2.zero
		self._opener.Position = UDim2.new(0, 20, 1, -74)
	end

	self:_render()
end

function ReportController:_render()
	local now = os.clock()
	local remaining = math.max(0, self._cooldownUntil - now)
	local retry = math.max(0, self._retryAt - now)
	local length = utf8.len(self._input.Text:gsub("^%s*(.-)%s*$", "%1"))
	local showStatus = self._success or remaining > 0

	self._form.Visible = not showStatus
	self._status.Visible = showStatus
	self._input.TextEditable = not self._pending
	self._form.Count.Text = string.format(uiConfig.count, utf8.len(self._input.Text) or 0, self._maximum)

	if showStatus then
		self._card.Header.Title.Text = if self._success then uiConfig.status.successTitle else uiConfig.status.cooldownTitle
		self._card.Header.Subtitle.Text = uiConfig.status.subtitle
		self._status.Badge.Check.Visible = self._success
		self._status.Badge.Clock.Visible = not self._success
		self._status.Message.Text = if self._success then uiConfig.status.success else uiConfig.status.cooldown
		self._status.Countdown.Text = if remaining > 0 then string.format(uiConfig.status.countdown, ReportText.duration(remaining)) else uiConfig.status.ready
	else
		self._card.Header.Title.Text = uiConfig.title
		self._card.Header.Subtitle.Text = uiConfig.subtitle
	end

	local valid = length ~= nil and length >= self._minimum and length <= self._maximum

	self._send.Interactable = valid and not self._pending and retry <= 0
	self._send.Selectable = self._send.Interactable
	self._send:SetAttribute("_fxOff", not self._send.Interactable)
	self._send.Face:SetAttribute("_fxOff", not self._send.Interactable)
	self._send.Face.Label.TextTransparency = if self._send.Interactable or self._pending then 0 else 0.45
	self._send.Face.Arrow.Visible = not self._pending and not self._typingLayout
	self._send.Face.Spinner.Visible = self._pending

	if self._pending then
		self._send.Face.Label.Text = uiConfig.buttons.sending
		self._form.Help.Text = uiConfig.sendingHelp
	elseif retry > 0 then
		self._send.Face.Label.Text = string.format(uiConfig.buttons.retryIn, math.ceil(retry))
		self._form.Help.Text = self._error or uiConfig.retryHelp
	else
		self._send.Face.Label.Text = if self._error then uiConfig.buttons.retry else uiConfig.buttons.send
		self._form.Help.Text = self._error or (if valid then uiConfig.help else string.format(uiConfig.minimum, self._minimum))
	end

	if self._typingLayout then
		self._send.Face.Label.Text = if self._pending then uiConfig.buttons.compactSending else if retry > 0 then string.format(uiConfig.buttons.compactRetry, math.ceil(retry)) else uiConfig.buttons.compactSend
	end

	self._form.Help.TextColor3 = if self._error and not self._pending then Color3.fromHex("ffbd96") else muted
end

function ReportController:Open()
	if not self._active or self._open or ModalGuard.blocks(self._dlg) then
		return
	end

	Scythe.clean(self._motion)

	self._open = true
	self._opener.Visible = false

	Scythe.clean(self._modalScope)

	local touchWasEnabled = guiServ.TouchControlsEnabled
	guiServ.TouchControlsEnabled = false

	Scythe.add(self._modalScope, function() guiServ.TouchControlsEnabled = touchWasEnabled end)

	self:Get("SprintController"):cancel()

	for _, name in {"sprint"} do
		local button = cas:GetButton(name) :: GuiButton?

		if button then
			local visible = button.Visible
			button.Visible = false

			Scythe.add(self._modalScope, function()
				if button.Parent then
					button.Visible = visible
				end
			end)
		end
	end

	self._success = self._success and self._cooldownUntil > os.clock()
	self._root.Visible = true

	self:_layout()
	self:_render()

	self._scale.Scale = 0.9
	self._dlg.GroupTransparency = 1
	self._scrim.BackgroundTransparency = 1

	spr.target(self._scale, 0.78, 5, {Scale = 1})
	Scythe.add(self._motion, function() spr.stop(self._scale) end)

	local fade = Scythe.add(self._motion, ts:Create(self._dlg, TweenInfo.new(0.18), {GroupTransparency = 0}), "Cancel")
	local dim = Scythe.add(self._motion, ts:Create(self._scrim, TweenInfo.new(0.18), {BackgroundTransparency = 0.45}), "Cancel")

	fade:Play()
	dim:Play()

	UISfx.play("Whoosh")

	if uis.PreferredInput == Enum.PreferredInput.Gamepad then
		guiServ.SelectedObject = if self._status.Visible then self._status.Done else self._input
	end
end

function ReportController:Close()
	if not self._open then
		return
	end

	self._open = false

	self._input:ReleaseFocus()

	ModalGuard.stampClose()
	Scythe.clean(self._motion)
	spr.target(self._scale, 1, 10, {Scale = 0.94})
	Scythe.add(self._motion, function() spr.stop(self._scale) end)

	local fade = Scythe.add(self._motion, ts:Create(self._dlg, TweenInfo.new(0.16), {GroupTransparency = 1}), "Cancel")
	local dim = Scythe.add(self._motion, ts:Create(self._scrim, TweenInfo.new(0.16), {BackgroundTransparency = 1}), "Cancel")

	Scythe.connect(self._motion, fade.Completed, function(state)
		if state == Enum.PlaybackState.Completed and not self._open then
			self._root.Visible = false
			self._opener.Visible = true

			Scythe.clean(self._modalScope)
		end
	end)

	fade:Play()
	dim:Play()

	if guiServ.SelectedObject and guiServ.SelectedObject:IsDescendantOf(self._root) then
		guiServ.SelectedObject = self._opener
	end
end

function ReportController:Submit()
	if not self._active or self._pending or not self._send.Interactable or ModalGuard.blocks(self._send) then
		return
	end

	local text = self._input.Text:gsub("^%s*(.-)%s*$", "%1")

	self._submittedText = self._input.Text

	Scythe.clean(self._requestScope)

	local id = httpServ:GenerateGUID(false)

	self._request = id
	self._pending = true
	self._error = nil

	self._input:ReleaseFocus()
	self:_render()

	local spinner = self._send.Face.Spinner
	spinner.Rotation = 0

	local spin = Scythe.add(self._requestScope, ts:Create(spinner, TweenInfo.new(0.8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Rotation = 360}), "Cancel")
	spin:Play()

	Scythe.addPromise(self._requestScope, Promise.delay(self._responseTimeout):andThen(function()
		if self._request == id and self._pending then
			self._pending = false
			self._error = uiConfig.errors.timeout
			self._retryAt = os.clock() + self._failurePenalty

			spin:Cancel()
			self:_render()
		end
	end))

	ReportPackets.Submit.send({requestId = id, encoded = ReportText.encode(text), device = self._device})
end

function ReportController:_result(result)
	if not self._active or result.requestId ~= self._request then
		return
	end

	Scythe.clean(self._requestScope)

	self._request = nil
	self._pending = false
	self._retryAt = 0

	if result.ok then
		self._success = true
		self._cooldownUntil = os.clock() + result.cooldown
		self._error = nil

		if self._input.Text == self._submittedText then
			self._input.Text = ""
		end

		self._status.Badge.Pop.Scale = 0.7

		spr.target(self._status.Badge.Pop, 0.7, 5, {Scale = 1})
		UISfx.play("Success")
	elseif result.reason == "cooldown" then
		self._cooldownUntil = os.clock() + result.remaining
		self._error = nil
	else
		self._error = uiConfig.errors[result.reason] or uiConfig.errors.default

		if result.reason == "filter" or result.reason == "send" or result.reason == "timeout" or result.reason == "internal" then
			self._retryAt = os.clock() + self._failurePenalty
		end

		if self._open then
			self._dlg.Rotation = -1

			spr.target(self._dlg, 0.65, 8, {Rotation = 0})
			UISfx.play("Negative")
		end
	end

	self:_render()
end

function ReportController:Init()
	local tabs = WaitFor:get(player.PlayerGui, "Tabs") :: typeof(game.StarterGui.Tabs)

	self._root = WaitFor:get(tabs, "Report") :: typeof(game.StarterGui.Tabs.Report)
	self._opener = tabs.ReportButton
	self._root.Visible = false
	self._opener.Visible = gameConfig.features.bugReports

	if not gameConfig.features.bugReports then
		return
	end

	self._wrap = self._root.FadeWrap
	self._dlg = self._wrap.Dlg
	self._card = self._dlg.Card
	self._form = self._card.Form
	self._status = self._card.Status
	self._input = self._form.InputFrame.Input
	self._send = self._form.Send
	self._opener.Face.Label.Text = uiConfig.opener
	self._card.Header.Eyebrow.Text = uiConfig.eyebrow
	self._form.Prompt.Text = uiConfig.prompt
	self._input.PlaceholderText = uiConfig.placeholder
	self._form.Footer.Text = uiConfig.footer
	self._status.Done.Face.Label.Text = uiConfig.buttons.done
	self._scrim = self._root.Scrim
	self._scale = self._dlg.MotionScale
	self._minimum = self._root:GetAttribute("MinLength") :: number
	self._maximum = self._root:GetAttribute("MaxLength") :: number
	self._responseTimeout = self._root:GetAttribute("ResponseTimeout") :: number
	self._failurePenalty = self._root:GetAttribute("FailurePenalty") :: number
	self._scope = Scythe.scope()

	Scythe.add(self._scope, self:Get("AutoScaleController"):attach(self._opener, "hud"))

	self._motion = Scythe.extend(self._scope)
	self._requestScope = Scythe.extend(self._scope)
	self._modalScope = Scythe.extend(self._scope)
	self._pointers = {}
	self._open = false
	self._pending = false
	self._success = false
	self._active = true
	self._cooldownUntil = 0
	self._retryAt = 0
	self._device = "PC"

	local platform = detectPlatform()

	if platform == Enum.Platform.MetaOS or uis.VREnabled then
		self._device = "VR"
	elseif platform == Enum.Platform.XBoxOne or platform == Enum.Platform.PS4 or platform == Enum.Platform.PS5 then
		self._device = "Console"
	elseif platform == Enum.Platform.IOS or platform == Enum.Platform.Android or platform == Enum.Platform.UWP then
		self._device = "Mobile"
	end

	local fx = self:Get("InteractFXController")

	for _, v in {self._opener, self._send, self._card.Close, self._status.Done} do
		fx:wireCandy(v, 0.1)
	end

	ModalGuard.register(self._root)
	Scythe.connect(self._scope, self._opener.Activated, function() self:Open() end)
	Scythe.connect(self._scope, self._send.Activated, function() self:Submit() end)

	for _, v in {self._card.Close, self._status.Done} do
		Scythe.connect(self._scope, v.Activated, function()
			if not ModalGuard.blocks(v) then
				self:Close()
			end
		end)
	end

	Scythe.add(self._scope, ModalGuard.onClickOutside(self._scrim, self._dlg, function()
		if not ModalGuard.blocks(self._scrim) then
			self:Close()
		end
	end))

	Scythe.connect(self._scope, self._input:GetPropertyChangedSignal("Text"), function()
		local text = ReportText.limit(self._input.Text, self._maximum)

		if text ~= self._input.Text then
			self._input.Text = text
		end

		self._error = nil

		self:_render()
	end)

	Scythe.connect(self._scope, self._root:GetPropertyChangedSignal("AbsoluteSize"), function() self:_queueLayout() end)
	Scythe.connect(self._scope, self._root:GetPropertyChangedSignal("AbsolutePosition"), function() self:_queueLayout() end)
	Scythe.connect(self._scope, self._form.InputFrame:GetPropertyChangedSignal("AbsoluteSize"), function()
		self._input.Size = UDim2.new(1, -28, 0, math.max(40, self._form.InputFrame.AbsoluteSize.Y - 24))
	end)

	Scythe.connect(self._scope, self._input:GetPropertyChangedSignal("AbsoluteSize"), function()
		if self._input:IsFocused() and self._input.CursorPosition >= #self._input.Text then
			self._form.InputFrame.CanvasPosition = Vector2.new(0, math.max(0, self._input.AbsoluteSize.Y + 12 - self._form.InputFrame.AbsoluteSize.Y))
		end
	end)

	Scythe.connect(self._scope, uis:GetPropertyChangedSignal("OnScreenKeyboardVisible"), function() self:_queueLayout() end)
	Scythe.connect(self._scope, uis:GetPropertyChangedSignal("OnScreenKeyboardPosition"), function() self:_queueLayout() end)
	Scythe.connect(self._scope, self._input.FocusLost, function(_, input)
		if input and input.UserInputState == Enum.UserInputState.Begin and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
			self._pointers[input] = true
		end

		self:_queueLayout()
	end)

	Scythe.connect(self._scope, self._input.Focused, function() self:_queueLayout() end)
	Scythe.connect(self._scope, uis:GetPropertyChangedSignal("TouchEnabled"), function() self:_queueLayout() end)
	Scythe.connect(self._scope, uis.InputBegan, function(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			self._pointers[input] = true
		end

		if self._open and not processed and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
			self:Close()
		end
	end)

	Scythe.connect(self._scope, uis.InputEnded, function(input)
		if self._pointers[input] then
			self._pointers[input] = nil

			self:_queueLayout()
		end
	end)

	Scythe.connect(self._scope, uis.WindowFocusReleased, function()
		table.clear(self._pointers)

		self:_queueLayout()
	end)

	Scythe.add(self._scope, ReportPackets.Result.listen(function(result) self:_result(result) end))
	Scythe.add(self._scope, Timer.simple(1, function()
		if self._active and self._open then
			self:_render()
		end
	end))

	self:_layout()
	self:_render()
end

function ReportController:Destroy()
	if not self._active then
		return
	end

	self._active = false
	self._open = false

	Scythe.destroy(self._scope)
	spr.stop(self._scale)
	spr.stop(self._dlg)
	spr.stop(self._status.Badge.Pop)

	self._input:ReleaseFocus()

	self._root.Visible = false
	self._opener.Visible = true
end

return ReportController