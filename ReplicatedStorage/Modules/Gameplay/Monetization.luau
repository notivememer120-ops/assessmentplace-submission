--!strict
local mps = game:GetService("MarketplaceService")
local rep = game:GetService("ReplicatedStorage")

local DevProducts = require(rep.Modules.Configs.Monetization.DevProducts)
local Gamepasses = require(rep.Modules.Configs.Monetization.Gamepasses)

local Monetization = {}
Monetization.ProductPurchaseFinished = mps.PromptProductPurchaseFinished
Monetization.GamePassPurchaseFinished = mps.PromptGamePassPurchaseFinished

local priceCache: {[string]: number} = {}

local function livePrice(id: number, infoType: Enum.InfoType): number?
	local key = infoType.Name .. id

	if priceCache[key] == nil then
		local s, info = pcall(function()
			return mps:GetProductInfoAsync(id, infoType)
		end)

		if s then
			priceCache[key] = info.PriceInRobux
		end
	end

	return priceCache[key]
end

function Monetization.productPrice(key: string): number
	local def = DevProducts[key]

	return livePrice(def.ProductId, Enum.InfoType.Product) or def.Price
end

function Monetization.gamepassPrice(key: string): number
	local def = Gamepasses[key]

	return livePrice(def.GamepassId, Enum.InfoType.GamePass) or def.Price
end

function Monetization.userOwnsGamepass(userId: number, gamepassId: number)
	return pcall(function()
		return mps:UserOwnsGamePassAsync(userId :: any, gamepassId)
	end)
end

function Monetization.promptProduct(player: Player, productKey: string)
	return pcall(function()
		mps:PromptProductPurchase(player, DevProducts[productKey].ProductId)
	end)
end

function Monetization.promptGamepass(player: Player, passKey: string)
	return pcall(function()
		mps:PromptGamePassPurchase(player, Gamepasses[passKey].GamepassId)
	end)
end

function Monetization.setProcessReceipt(handler)
	mps.ProcessReceipt = handler
end

return Monetization