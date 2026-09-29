--!strict
local rep = game:GetService("ReplicatedStorage")

local config = require(rep.Modules.Configs.CampUIConfig)
local items = require(rep.Modules.Configs.ShopConfig)
local buyQuery = require(rep.Modules.Packets.ShopPackets).queries.Buy
local CoinText = require(rep.Modules.Gameplay.CoinText)
local DataService = require(rep.Modules.Imported.Backend.DataService).client
local Promise = require(rep.Modules.Imported.Backend.Promise)
local Scythe = require(rep.Modules.Imported.Utility.Scythe)
local UISfx = require(rep.Modules.Gameplay.UISfx)

type Controller = {
	__slittttName: string,
	Dependencies: {string},
	_scope: Scythe.Scope,
	_menu: typeof(require(script.Parent.CampMenuController)),
	_shop: typeof(game.StarterGui.Tabs.CampMenu.FadeWrap.Dlg.Card.Shop),
	_request: number,
	_pending: boolean,
	_statusText: string,
	Get: (Controller, "CampMenuController") -> typeof(require(script.Parent.CampMenuController)),
	_status: (Controller, string) -> (),
	_render: (Controller) -> (),
	Buy: (Controller, string) -> (),
	Init: (Controller) -> (),
	Destroy: (Controller) -> (),
}

local ShopController = {} :: Controller
ShopController.__slittttName = "ShopController"
ShopController.Dependencies = {"CampMenuController"}

function ShopController:_status(text)
	self._statusText = text

	if self._menu.Current == "Shop" then self._menu.Card.Footer.Status.Text = text end
end

function ShopController:_render()
	self._menu.Card.Header.Wallet.Amount.Text = CoinText(DataService:get("cash"))

	for _, v in config.equipment do
		local info = (self._shop.Equipment:FindFirstChild(v.row) :: typeof(game.StarterGui.Tabs.CampMenu.FadeWrap.Dlg.Card.Shop.Equipment.Taser)).Info
		local count = DataService:get({"items", v.key})

		info.Owned.Text = `{count} owned`

		local buy = info.Buy
		local allowed = not self._pending

		buy.Interactable = allowed
		buy.Selectable = allowed
		buy:SetAttribute("_fxOff", not allowed)
		buy.Face:SetAttribute("_fxOff", not allowed)
		buy.Face.Label.Text = if self._pending then "BUYING..." else "BUY"
		buy.Face.BackgroundTransparency = if allowed then 0 else 0.25
		buy.Face.Label.TextTransparency = if allowed then 0 else 0.25
	end
end

function ShopController:Buy(key)
	if self._pending then return end

	self._pending = true
	self._request += 1

	local id = self._request

	self:_status(`Buying {(items.Get(key) :: items.Item).title}...`)
	self:_render()

	Scythe.addPromise(self._scope, Promise.try(function()
		return buyQuery.invoke({id = id, key = key})
	end):andThen(function(result)
		self._pending = false

		self:_status(config.copy[result])
		self:_render()

		UISfx.play(if result == "ok" then "Success" else "Negative")
	end):catch(function(err)
		self._pending = false

		self:_status(config.copy.failed)
		self:_render()

		task.spawn(error, err)
	end))
end

function ShopController:Init()
	self._scope = Scythe.scope()
	self._menu = self:Get("CampMenuController")
	self._shop = self._menu.Card.Shop
	self._request = 0
	self._pending = false

	for _, v in self._shop:GetChildren() do
		if v:IsA("GuiObject") then v.Visible = v.Name == "Equipment" or v.Name == "TabBar" end
	end

	for _, v in self._shop.TabBar:GetChildren() do
		if v:IsA("GuiButton") then v.Visible = v.Name == "1" end
	end

	local tab = self._shop.TabBar["1"]
	tab.Face.Label.Text = config.categories[1]
	tab.Face.Label.TextColor3 = config.colors.amber
	tab.Face.Underline.Visible = true

	self._menu:Wire(tab, function() self:_status(config.copy.shopFooter) end)

	for _, v in self._shop.Equipment:GetChildren() do
		if v:IsA("Frame") then v.Visible = false end
	end

	for _, v in self._shop:GetDescendants() do
		if v:IsA("ViewportFrame") then v.Visible = false end
	end

	for _, v in config.equipment do
		local row = self._shop.Equipment:FindFirstChild(v.row) :: typeof(game.StarterGui.Tabs.CampMenu.FadeWrap.Dlg.Card.Shop.Equipment.Taser)
		local item = items.Get(v.key) :: items.Item

		row.Visible = true
		row.Art.Visible = false

		local info = row.Info
		info.Category.Text = "ITEM"
		info.Title.Text = item.title
		info.Description.Text = item.description
		info.Use.Visible = false
		info.Inventory.Text = "INVENTORY"
		info.Buy.Face.Price.Amount.Text = CoinText(item.price)

		self._menu:Wire(info.Buy, function() self:Buy(v.key) end)
	end

	Scythe.connect(self._scope, DataService:getChangedSignal("cash"), function() self:_render() end)
	Scythe.connect(self._scope, DataService:getChangedSignal("items"), function() self:_render() end)
	Scythe.connect(self._scope, self._menu.Changed, function(name)
		if name == "Shop" then
			self:_status(self._statusText)
			self:_render()
		end
	end)

	self:_status(config.copy.shopFooter)
	self:_render()
end

function ShopController:Destroy()
	Scythe.destroy(self._scope)
end

return ShopController