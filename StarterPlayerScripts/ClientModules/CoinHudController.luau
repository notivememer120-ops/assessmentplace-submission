--!strict
local rep = game:GetService("ReplicatedStorage")
local guiServ = game:GetService("GuiService")
local uis = game:GetService("UserInputService")
local ts = game:GetService("TweenService")
local player = game:GetService("Players").LocalPlayer :: Player

local config = require(rep.Modules.Configs.CoinHudConfig)
local CoinText = require(rep.Modules.Gameplay.CoinText)
local DataService = require(rep.Modules.Imported.Backend.DataService).client
local WaitFor = require(rep.Modules.Gameplay.WaitFor)
local Loading = require(rep.Modules.Gameplay.LoadingScreenEvents)
local ModalGuard = require(rep.Modules.Gameplay.ModalGuard)
local Timer = require(rep.Modules.Imported.Backend.Timer)
local Scythe = require(rep.Modules.Imported.Utility.Scythe)

local CoinHudController = {}
CoinHudController.__slittttName = "CoinHudController"
CoinHudController.Dependencies = {"AutoScaleController", "CampMenuController", "ReportController"}

type Controller = typeof(CoinHudController) & {
	_scope: Scythe.Scope,
	_pickupScope: Scythe.Scope,
	_gui: typeof(game.StarterGui.CoinHUD),
	_root: typeof(game.StarterGui.CoinHUD.Root),
	_wallet: typeof(game.StarterGui.CoinHUD.Root.Wallet),
	_content: typeof(game.StarterGui.CoinHUD.Root.Wallet.Face.Content),
	_amount: TextLabel,
	_gain: TextLabel,
	_tabs: typeof(game.StarterGui.Tabs),
	_report: GuiButton,
	_walletScale: UIScale,
	_cashValue: number?,
	Get: (Controller, "AutoScaleController") -> typeof(require(script.Parent.AutoScaleController)),
}

function CoinHudController._layout(self: Controller)
	if not self._root.Visible then return end

	local scale = self._walletScale.Scale
	local width = math.max(config.walletWidth, self._content.UIListLayout.AbsoluteContentSize.X / scale + 24)

	self._wallet.Size = UDim2.fromOffset(width, config.walletHeight)

	local margin = if uis.TouchEnabled then config.mobileMargin else config.margin
	local top = if uis.TouchEnabled then config.gap else config.walletTop

	if uis.TouchEnabled and self._tabs.Enabled and self._report.Visible then
		local left = self._root.AbsolutePosition.X + self._root.AbsoluteSize.X - margin - width * scale
		local report = self._report.AbsolutePosition
		local size = self._report.AbsoluteSize

		if report.X + size.X > left and report.Y < self._root.AbsolutePosition.Y + top + config.walletHeight * scale then
			top = math.max(top, report.Y + size.Y - self._root.AbsolutePosition.Y + config.gap)
		end
	end

	self._wallet.Position = UDim2.new(1, -margin, 0, top)
end

function CoinHudController._cash(self: Controller)
	local cash = DataService:get("cash")
	local previous = self._cashValue
	self._cashValue = cash
	self._amount.Text = CoinText(cash)

	Scythe.clean(self._pickupScope)

	self._wallet.Face.Pulse.Scale = 1
	self._gain.Visible = false

	if previous and cash > previous and self._root.Visible then
		self._gain.Text = `+{CoinText(cash - previous)}`
		self._gain.TextTransparency = 0
		self._gain.Visible = true

		if not guiServ.ReducedMotionEnabled then
			self._wallet.Face.Pulse.Scale = 1.035

			Scythe.add(self._pickupScope, ts:Create(self._wallet.Face.Pulse, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {Scale = 1}), "Cancel"):Play()
			Scythe.add(self._pickupScope, ts:Create(self._gain, TweenInfo.new(config.pickupSeconds), {TextTransparency = 1}), "Cancel"):Play()
		end

		Scythe.add(self._pickupScope, task.delay(config.pickupSeconds, function() self._gain.Visible = false end))
	end
end

function CoinHudController._refresh(self: Controller)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local visible = Loading.HasHidden and hum and hum.Health > 0 and not ModalGuard.anyOpen() and not guiServ.MenuIsOpen

	self._root.Visible = visible == true

	if self._root.Visible then self:_layout() end
end

function CoinHudController.Init(self: Controller)
	self._scope = Scythe.scope()
	self._pickupScope = Scythe.extend(self._scope)
	self._gui = WaitFor:get(player.PlayerGui, "CoinHUD") :: typeof(game.StarterGui.CoinHUD)
	self._root = self._gui.Root
	self._wallet = self._root.Wallet
	self._content = self._wallet.Face.Content
	self._amount = self._content.Amount
	self._gain = self._wallet.Gain
	self._tabs = WaitFor:get(player.PlayerGui, "Tabs") :: typeof(game.StarterGui.Tabs)
	self._report = self._tabs.ReportButton
	self._walletScale = Scythe.add(self._scope, self:Get("AutoScaleController"):attach(self._wallet, "hud"))
	self._gui.Enabled = true
	self._root.Visible = false
	self._cashValue = nil

	self:_cash()

	Scythe.connect(self._scope, DataService:getChangedSignal("cash"), function() self:_cash() end)
	Scythe.connect(self._scope, self._content.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function() self:_layout() end)
	Scythe.connect(self._scope, player.CharacterRemoving, function()
		self._root.Visible = false
	end)

	local timer = Scythe.add(self._scope, Timer.new(config.updateSeconds))

	Scythe.connect(self._scope, timer.Tick, function() self:_refresh() end)

	timer:Start()
	self:_refresh()
end

function CoinHudController.Destroy(self: Controller)
	self._root.Visible = false

	Scythe.destroy(self._scope)

	self._wallet.Face.Pulse.Scale = 1
	self._gain.Visible = false
end

return CoinHudController