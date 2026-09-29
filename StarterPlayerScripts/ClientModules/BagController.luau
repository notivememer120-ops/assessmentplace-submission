--!strict
local rep = game:GetService("ReplicatedStorage")
local guiServ = game:GetService("GuiService")
local uis = game:GetService("UserInputService")
local player = game:GetService("Players").LocalPlayer :: Player

local config = require(rep.Modules.Configs.AssessmentConfig)
local query = require(rep.Modules.Packets.BagPackets).queries.Upgrade
local DataService = require(rep.Modules.Imported.Backend.DataService).client
local WaitFor = require(rep.Modules.Gameplay.WaitFor)
local Loading = require(rep.Modules.Gameplay.LoadingScreenEvents)
local ModalGuard = require(rep.Modules.Gameplay.ModalGuard)
local UISfx = require(rep.Modules.Gameplay.UISfx)
local Timer = require(rep.Modules.Imported.Backend.Timer)
local Promise = require(rep.Modules.Imported.Backend.Promise)
local Scythe = require(rep.Modules.Imported.Utility.Scythe)

local BagController = {}
BagController.__slittttName = "BagController"
BagController.Dependencies = {"CoinHudController", "WorldGuiController"}

type Controller = typeof(BagController) & {
	_scope: Scythe.Scope,
	_pending: boolean,
	_statusUntil: number,
	_colors: typeof(require(rep.Modules.Configs.CampUIConfig).colors),
	_gui: typeof(game.StarterGui.BagHUD),
	_root: typeof(game.StarterGui.BagHUD.Root),
	_bag: typeof(game.StarterGui.BagHUD.Root.Bag),
	_progress: typeof(game.StarterGui.BagHUD.Root.Progress),
	_gateLabel: TextLabel,
	_gateText: string,
	_wallet: typeof(game.StarterGui.CoinHUD.Root.Wallet),
	Get: (Controller, "WorldGuiController") -> typeof(require(script.Parent.WorldGuiController)),
}

function BagController._render(self: Controller)
	local count = player:GetAttribute("BagCount") :: number?
	local capacity = player:GetAttribute("BagCapacity") :: number?

	if count == nil or capacity == nil then return end

	local level = player:GetAttribute("BagLevel") :: number
	local owned = level >= 2
	local mobile = uis.TouchEnabled
	local status = os.clock() < self._statusUntil

	self._bag.Title.Text = if mobile then `BAG / L{level}` else "BAG"
	self._bag.Count.Text = `{count} / {capacity}`
	self._bag.Track.Fill.Size = UDim2.fromScale(count / capacity, 1)
	self._bag.Hint.Text = if count >= capacity then "Bag full. Head to Deposit." elseif count > 0 then `Deposit for {count * config.coinValue} coins.` else "Walk near items to collect."

	local button = self._bag.Upgrade
	button.Text = if self._pending then "Buying..." elseif owned then "Bag upgraded" else `Upgrade bag - {config.upgradePrice}`

	if mobile and status and not self._pending then button.Text = self._bag.Status.Text end

	button.Visible = not mobile or not owned
	button.Interactable = not owned and not self._pending
	button.Selectable = button.Interactable
	button.BackgroundColor3 = if owned then self._colors.inner else self._colors.amber
	button.TextColor3 = if owned then self._colors.muted else self._colors.ink
	self._bag.Hint.Visible = not mobile or owned
	self._bag.Track.Visible = not mobile
	self._bag.Status.Visible = not mobile

	if mobile and owned and status then self._bag.Hint.Text = self._bag.Status.Text end

	if os.clock() >= self._statusUntil then self._bag.Status.Text = `Level {level}` end

	local collected = (workspace:GetAttribute("Zone1Collected") :: number?) or 0
	local total = (workspace:GetAttribute("TotalCollected") :: number?) or 0
	local open = workspace:GetAttribute("Zone2Open")

	self._gateLabel.Text = if open then "Open for everyone" else self._gateText
	self._progress.Title.Text = if total == config.zone1Count + config.zone2Count then "ALL 20 COLLECTED" elseif open then `ZONE 2   {total - collected} / {config.zone2Count}` else `ZONE 1   {collected} / {config.zone1Count}`
	self._progress.Detail.Text = if total == 20 then "Deposit any items still in your bag" elseif open then "Gate open for everyone" else "Collect together to open Zone 2"
end

function BagController._upgrade(self: Controller)
	if self._pending then return end

	self._pending = true

	self:_render()

	Scythe.addPromise(self._scope, Promise.try(function()
		return query.invoke(nil)
	end):andThen(function(result)
		self._pending = false
		self._statusUntil = os.clock() + 3
		self._bag.Status.Text = if result == "ok" then "Capacity increased to 10" elseif result == "funds" then `Need {math.max(0, config.upgradePrice - DataService:get("cash"))} more coins` elseif result == "owned" then "Already upgraded" else "Try again in a moment"

		UISfx.play(if result == "ok" then "Success" else "Negative")

		self:_render()
	end):catch(function(err)
		self._pending = false
		self._statusUntil = os.clock() + 4
		self._bag.Status.Text = "Couldn't confirm. Try again."

		self:_render()

		task.spawn(error, err)
	end))
end

function BagController._refresh(self: Controller)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")

	self._root.Visible = Loading.HasHidden and hum ~= nil and hum.Health > 0 and player:GetAttribute("BagCapacity") ~= nil and not ModalGuard.anyOpen() and not guiServ.MenuIsOpen

	if not self._root.Visible then return end

	local margin = if uis.TouchEnabled then 12 else 24
	local top = self._wallet.AbsolutePosition.Y + self._wallet.AbsoluteSize.Y - self._root.AbsolutePosition.Y + 10

	self._bag.Position = UDim2.new(1, -margin, 0, top)

	local mobile = uis.TouchEnabled
	local owned = (player:GetAttribute("BagLevel") :: number) >= 2

	self._bag.Size = UDim2.fromOffset(if mobile then 196 else 208, if mobile then (if owned then 80 else 88) else 176)
	self._bag.Title.Position = UDim2.fromOffset(12, if mobile then 8 else 12)
	self._bag.Title.Size = UDim2.fromOffset(if mobile then 80 else 64, 20)
	self._bag.Title.TextSize = if mobile then 12 else 14
	self._bag.Count.Position = UDim2.new(1, -12, 0, if mobile then 4 else 8)
	self._bag.Count.Size = UDim2.fromOffset(if mobile then 92 else 108, 28)
	self._bag.Count.TextSize = if mobile then 22 else 24
	self._bag.Hint.Position = UDim2.fromOffset(12, if mobile then 36 else 56)
	self._bag.Upgrade.Position = UDim2.fromOffset(12, if mobile then 36 else 96)
	self._bag.Upgrade.TextSize = if mobile then 14 else 15
	self._progress.Size = UDim2.fromOffset(if uis.TouchEnabled then 224 else 240, 58)

	self:_render()
end

function BagController.Init(self: Controller)
	self._scope = Scythe.scope()
	self._pending = false
	self._statusUntil = 0
	self._colors = require(rep.Modules.Configs.CampUIConfig).colors
	self._gui = WaitFor:get(player.PlayerGui, "BagHUD") :: typeof(game.StarterGui.BagHUD)
	self._root = self._gui.Root
	self._bag = self._root.Bag
	self._progress = self._root.Progress
	self._gateLabel = (self:Get("WorldGuiController"):GetGui("AssessmentGate") :: typeof(rep.Assets.WorldGuiTemplates.AssessmentGate)).Plate.Body.Detail
	self._gateText = self._gateLabel.Text
	self._wallet = (WaitFor:get(player.PlayerGui, "CoinHUD") :: typeof(game.StarterGui.CoinHUD)).Root.Wallet
	self._gui.Enabled = true
	self._root.Visible = false

	Scythe.connect(self._scope, self._bag.Upgrade.Activated, function() self:_upgrade() end)

	for _, v in {"BagCount", "BagCapacity", "BagLevel"} do
		Scythe.connect(self._scope, player:GetAttributeChangedSignal(v), function() self:_render() end)
	end

	for _, v in {"Zone1Collected", "Zone2Open", "TotalCollected"} do
		Scythe.connect(self._scope, workspace:GetAttributeChangedSignal(v), function() self:_render() end)
	end

	local timer = Scythe.add(self._scope, Timer.new(0.1))

	Scythe.connect(self._scope, timer.Tick, function() self:_refresh() end)

	timer:Start()
	self:_refresh()
end

function BagController.Destroy(self: Controller)
	self._root.Visible = false

	Scythe.destroy(self._scope)
end

return BagController