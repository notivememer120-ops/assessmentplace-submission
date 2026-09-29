--!strict
local rep = game:GetService("ReplicatedStorage")
local config = require(rep.Modules.Configs.CampUIConfig)
local Scythe = require(rep.Modules.Imported.Utility.Scythe)
local spr = require(rep.Modules.Imported.Backend.spr)

type ToggleRow = typeof(game.StarterGui.Tabs.CampMenu.FadeWrap.Dlg.Card.Settings.muteMusic)

type ModeRow = typeof(game.StarterGui.Tabs.CampMenu.FadeWrap.Dlg.Card.Settings.sprintToggle)

type Controller = {
	__slittttName: string,
	Dependencies: {string},
	_scope: Scythe.Scope,
	_menu: typeof(require(script.Parent.CampMenuController)),
	_settings: typeof(require(script.Parent.SettingsTopbar)),
	Get: ((Controller, "CampMenuController") -> typeof(require(script.Parent.CampMenuController)))
		& ((Controller, "SettingsTopbar") -> typeof(require(script.Parent.SettingsTopbar))),
	_render: (Controller) -> (),
	Init: (Controller) -> (),
	Destroy: (Controller) -> (),
}

local SettingsController = {} :: Controller
SettingsController.__slittttName = "SettingsController"
SettingsController.Dependencies = {"SettingsTopbar", "CampMenuController"}

function SettingsController:_render()
	local colors = config.colors

	for _, v in config.settings do
		local row = self._menu.Card.Settings:FindFirstChild(v.key) :: Frame
		local value = self._settings:GetValue(v.key)
		local on = if v.inverse then not value else value

		if v.mode then
			for _, name in {"Toggle", "Hold"} do
				local selected = value == (name == "Toggle")
				local button = row:FindFirstChild(name) :: typeof(game.StarterGui.Tabs.CampMenu.FadeWrap.Dlg.Card.Settings.sprintToggle.Toggle)
				button.Face.BackgroundColor3 = if selected then colors.amber else colors.inner
				button.Face.Label.TextColor3 = if selected then colors.ink else colors.cream
			end
		else
			local toggle = (row :: ToggleRow).Toggle
			toggle.Face.Label.Text = if on then "ON" else "OFF"
			toggle.Face.Label.Position = UDim2.fromOffset(if on then 0 else 44, 0)
			toggle.Face.Label.TextColor3 = if on then colors.ink else colors.cream
			toggle.Face.BackgroundColor3 = if on then colors.amber else colors.inner

			spr.target(toggle.Face.Knob, 1, 7, {Position = UDim2.fromOffset(if on then 62 else 10, 5)})
		end
	end

	if self._menu.Current == "Settings" then self._menu.Card.Footer.Status.Text = self._settings.Status end
end

function SettingsController:Init()
	self._scope = Scythe.scope()
	self._menu = self:Get("CampMenuController")
	self._settings = self:Get("SettingsTopbar")

	for _, v in config.settings do
		local row = self._menu.Card.Settings:FindFirstChild(v.key) :: Frame

		self._menu:Wire(row:FindFirstChild("Toggle") :: GuiButton, function()
			self._settings:SetValue(v.key, if v.mode then true else not self._settings:GetValue(v.key))
		end)

		if v.mode then self._menu:Wire((row :: ModeRow).Hold, function() self._settings:SetValue(v.key, false) end) end
	end

	Scythe.connect(self._scope, self._settings.Changed, function() self:_render() end)
	Scythe.connect(self._scope, self._settings.SaveChanged, function() self:_render() end)
	Scythe.connect(self._scope, self._menu.Changed, function() self:_render() end)

	self:_render()
end

function SettingsController:Destroy()
	Scythe.destroy(self._scope)

	for _, v in config.settings do
		if not v.mode then spr.stop((self._menu.Card.Settings:FindFirstChild(v.key) :: ToggleRow).Toggle.Face.Knob) end
	end
end

return SettingsController