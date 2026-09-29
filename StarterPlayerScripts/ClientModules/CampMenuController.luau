--!strict
local rep = game:GetService("ReplicatedStorage")
local player = game:GetService("Players").LocalPlayer :: Player
local uis = game:GetService("UserInputService")
local guiServ = game:GetService("GuiService")
local cas = game:GetService("ContextActionService")
local ts = game:GetService("TweenService")

local WaitFor = require(rep.Modules.Gameplay.WaitFor)
local ModalGuard = require(rep.Modules.Gameplay.ModalGuard)
local Loading = require(rep.Modules.Gameplay.LoadingScreenEvents)
local UISfx = require(rep.Modules.Gameplay.UISfx)
local Signal = require(rep.Modules.Imported.Utility.Signal)
local Scythe = require(rep.Modules.Imported.Utility.Scythe)
local spr = require(rep.Modules.Imported.Backend.spr)

type Controller = {
	__slittttName: string,
	Dependencies: {string},
	Changed: typeof(Signal()),
	Current: string?,
	Root: typeof(game.StarterGui.Tabs.CampMenu),
	Hud: typeof(game.StarterGui.Tabs.CampHud),
	Card: typeof(game.StarterGui.Tabs.CampMenu.FadeWrap.Dlg.Card),
	_wrap: typeof(game.StarterGui.Tabs.CampMenu.FadeWrap),
	_dlg: typeof(game.StarterGui.Tabs.CampMenu.FadeWrap.Dlg),
	_scrim: Frame,
	_hudScale: UIScale,
	_scope: Scythe.Scope,
	_motion: Scythe.Scope,
	_modal: Scythe.Scope,
	Get: ((Controller, "AutoScaleController") -> typeof(require(script.Parent.AutoScaleController)))
		& ((Controller, "InteractFXController") -> typeof(require(script.Parent.InteractFXController)))
		& ((Controller, "SprintController") -> typeof(require(script.Parent.SprintController))),
	_layout: (Controller) -> (),
	Wire: (Controller, GuiButton, () -> ()) -> (),
	Open: (Controller, string) -> (),
	Close: (Controller) -> (),
	Init: (Controller) -> (),
	Destroy: (Controller) -> (),
}

local CampMenuController = {} :: Controller
CampMenuController.__slittttName = "CampMenuController"
CampMenuController.Dependencies = {"AutoScaleController", "InteractFXController", "SprintController"}
CampMenuController.Changed = Signal()

function CampMenuController:_layout()
	local size = self.Root.AbsoluteSize
	local compact = size.Y < 480
	local design = Vector2.new(math.min(if compact then 710 else 740, size.X - (if compact then 80 else 100)), math.min(520, size.Y - (if compact then 16 else 82)))

	self._wrap.Size = UDim2.fromOffset(design.X, design.Y)
	self._wrap.FitScale.Scale = self:Get("AutoScaleController"):fit(design, size - Vector2.new(24, 24))

	local full = guiServ:GetInsetArea(Enum.ScreenInsets.None)

	self._scrim.Position = UDim2.fromOffset(full.Min.X - self.Root.AbsolutePosition.X, full.Min.Y - self.Root.AbsolutePosition.Y)
	self._scrim.Size = UDim2.fromOffset(full.Width, full.Height)

	local height = if compact then 52 else 90
	local footer = if compact then 24 else 36

	self.Card.Header.Size = UDim2.new(1, 0, 0, height)
	self.Card.Header.Title.TextSize = if compact then 27 else 36
	self.Card.Header.Wallet.Amount.TextSize = if compact then 20 else 24
	self.Card.Header.Wallet.Icon.Size = UDim2.fromOffset(if compact then 24 else 28, if compact then 24 else 28)
	self.Card.Close.Position = UDim2.new(1, -74, 0, (height - 46) / 2)
	self.Card.Footer.Position = UDim2.new(0, 28, 1, -footer)
	self.Card.Footer.Size = UDim2.new(1, -56, 0, footer)
	self.Card.Settings.Position = UDim2.fromOffset(28, height + 12)
	self.Card.Settings.Size = UDim2.new(1, -56, 1, -height - footer - 24)
	self.Card.Shop.Position = UDim2.fromOffset(0, height)
	self.Card.Shop.Size = UDim2.new(1, 0, 1, -height - footer)

	local shop = self.Card.Shop
	local tabHeight = if compact then 40 else 47
	local top = tabHeight + (if compact then 12 else 18)

	shop.TabBar.Size = UDim2.new(1, 0, 0, tabHeight)
	shop.TabBar["1"].Size = UDim2.fromOffset(82, tabHeight)
	shop.TabBar["1"].Face.Label.TextSize = if compact then 12 else 13
	shop.Equipment.Position = UDim2.fromOffset(23, top)
	shop.Equipment.Size = UDim2.new(1, -46, 1, -top - 10)

	for _, v in shop.Equipment:GetChildren() do
		if not v:IsA("Frame") or not v.Visible then continue end

		v.Size = UDim2.new(1, 0, 0, if compact then 160 else 218)

		local pad = if compact then 13 else 18
		local info = (v :: typeof(game.StarterGui.Tabs.CampMenu.FadeWrap.Dlg.Card.Shop.Equipment.Taser)).Info
		info.Position = UDim2.fromOffset(pad, pad)
		info.Size = UDim2.new(1, -pad * 2, 1, -pad * 2)
		info.Category.Visible = not compact
		info.Title.Position = UDim2.fromOffset(0, if compact then 0 else 14)
		info.Title.Size = UDim2.new(1, 0, 0, if compact then 28 else 34)
		info.Title.TextSize = if compact then 23 else 28
		info.Description.Position = UDim2.fromOffset(0, if compact then 32 else 51)
		info.Description.Size = UDim2.new(1, 0, 0, if compact then 28 else 24)
		info.Use.Position = UDim2.fromOffset(0, if compact then 57 else 76)
		info.Line.Position = UDim2.fromOffset(0, if compact then 73 else 102)
		info.Inventory.Position = UDim2.fromOffset(0, if compact then 79 else 108)
		info.Owned.Position = info.Inventory.Position
		info.Buy.Position = UDim2.new(0, 0, 1, if compact then -44 else -47)
		info.Buy.Size = UDim2.new(1, 0, 0, if compact then 44 else 47)
		info.Buy.Face.Price.Amount.TextSize = 20
	end

	self.Hud.Position = UDim2.new(0, if uis.TouchEnabled then 12 else 24, if uis.TouchEnabled then 0 else 0.45, if uis.TouchEnabled then 12 else -62)
end

function CampMenuController:Wire(button, callback)
	self:Get("InteractFXController"):wireCandy(button, 0.1)

	Scythe.connect(self._scope, button.Activated, function()
		if button.Interactable and not ModalGuard.blocks(button) then callback() end
	end)
end

function CampMenuController:Open(name)
	if not Loading.HasHidden or ModalGuard.blocks(self.Card) then return end

	local fresh = not self.Current

	Scythe.clean(self._motion)

	self.Current = name
	self.Root.Visible = true
	self.Hud.Visible = false
	self.Card.Header.Title.Text = name
	self.Card.Header.Wallet.Visible = name == "Shop"
	self.Card.Shop.Visible = name == "Shop"
	self.Card.Settings.Visible = name == "Settings"

	self:_layout()

	if fresh then
		Scythe.clean(self._modal)

		local touch = guiServ.TouchControlsEnabled
		local navigation = guiServ.GuiNavigationEnabled

		guiServ.TouchControlsEnabled = false
		guiServ.GuiNavigationEnabled = true

		Scythe.add(self._modal, function()
			guiServ.TouchControlsEnabled = touch
			guiServ.GuiNavigationEnabled = navigation
		end)

		self:Get("SprintController"):cancel()

		local actions = cas:GetAllBoundActionInfo()
		local button = if actions.sprint then cas:GetButton("sprint") :: GuiButton? else nil

		if button then
			local visible = button.Visible
			button.Visible = false

			Scythe.add(self._modal, function() if button.Parent then button.Visible = visible end end)
		end
	end

	self._dlg.MotionScale.Scale = if guiServ.ReducedMotionEnabled then 1 else 0.94
	self._dlg.GroupTransparency = 1

	spr.target(self._dlg.MotionScale, 0.85, 6, {Scale = 1})
	Scythe.add(self._motion, function() spr.stop(self._dlg.MotionScale) end)

	Scythe.add(self._motion, ts:Create(self._dlg, TweenInfo.new(0.15), {GroupTransparency = 0}), "Cancel"):Play()
	Scythe.add(self._motion, ts:Create(self._scrim, TweenInfo.new(0.15), {BackgroundTransparency = 0.45}), "Cancel"):Play()

	UISfx.play("Whoosh")

	self.Changed:Fire(name)

	if uis.PreferredInput == Enum.PreferredInput.Gamepad then
		guiServ.SelectedObject = if name == "Shop" then self.Card.Shop.TabBar["1"] else self.Card.Settings.muteMusic.Toggle
	end
end

function CampMenuController:Close()
	if not self.Current then return end

	local name = self.Current
	self.Current = nil

	Scythe.clean(self._motion)
	Scythe.clean(self._modal)

	self.Root.Visible = false
	self.Hud.Visible = true

	ModalGuard.stampClose()

	self.Changed:Fire(nil)

	if guiServ.SelectedObject and guiServ.SelectedObject:IsDescendantOf(self.Root) then
		guiServ.SelectedObject = self.Hud:FindFirstChild(name) :: GuiButton
	end
end

function CampMenuController:Init()
	self._scope = Scythe.scope()
	self._motion = Scythe.extend(self._scope)
	self._modal = Scythe.extend(self._scope)

	local navigation = guiServ.GuiNavigationEnabled
	local autoSelect = guiServ.AutoSelectGuiEnabled

	guiServ.GuiNavigationEnabled = true
	guiServ.AutoSelectGuiEnabled = true

	Scythe.add(self._scope, function()
		guiServ.GuiNavigationEnabled = navigation
		guiServ.AutoSelectGuiEnabled = autoSelect
	end)

	local tabs = WaitFor:get(player.PlayerGui, "Tabs") :: typeof(game.StarterGui.Tabs)

	self.Root = WaitFor:get(tabs, "CampMenu") :: typeof(game.StarterGui.Tabs.CampMenu)
	self.Hud = tabs.CampHud
	self.Hud.Size = UDim2.fromOffset(164, 124)

	for _, v in self.Hud:GetChildren() do
		if v:IsA("GuiButton") and v.Name ~= "Shop" and v.Name ~= "Settings" then v.Visible = false end
	end

	self._wrap = self.Root.FadeWrap
	self._dlg = self._wrap.Dlg
	self.Card = self._dlg.Card
	self._scrim = self.Root.Scrim
	self.Root.Visible = false
	self._hudScale = self:Get("AutoScaleController"):attach(self.Hud, "hud")

	Scythe.add(self._scope, self._hudScale)
	Scythe.add(self._scope, ModalGuard.register(self.Root))

	for _, v in {"Shop", "Settings"} do self:Wire(self.Hud:FindFirstChild(v) :: GuiButton, function() self:Open(v) end) end

	self:Wire(self.Card.Close, function() self:Close() end)

	Scythe.add(self._scope, ModalGuard.onClickOutside(self._scrim, self.Card, function() self:Close() end))
	Scythe.connect(self._scope, self.Root:GetPropertyChangedSignal("AbsoluteSize"), function() self:_layout() end)
	Scythe.connect(self._scope, self.Root:GetPropertyChangedSignal("AbsolutePosition"), function() self:_layout() end)
	Scythe.connect(self._scope, uis:GetPropertyChangedSignal("TouchEnabled"), function() self:_layout() end)
	Scythe.connect(self._scope, uis.InputBegan, function(input, processed)
		if self.Current and not processed and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then self:Close() end
	end)

	Scythe.connect(self._scope, player.CharacterRemoving, function() self:Close() end)
	Scythe.connect(self._scope, tabs:GetPropertyChangedSignal("Enabled"), function()
		if not tabs.Enabled then self:Close() end
	end)

	self:_layout()
end

function CampMenuController:Destroy()
	self:Close()

	Scythe.destroy(self._scope)
end

return CampMenuController