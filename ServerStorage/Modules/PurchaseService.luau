--!strict
local players = game:GetService("Players")
local rep = game:GetService("ReplicatedStorage")

local DevProducts = require(rep.Modules.Configs.Monetization.DevProducts)
local DataService = require(rep.Modules.Imported.Backend.DataService).server
local Monetization = require(rep.Modules.Gameplay.Monetization)

local DataManager: typeof(require(script.Parent.DataManager))
local NotifyService: typeof(require(script.Parent.NotifyService))

local PurchaseService = {}

PurchaseService.__slittttName = "PurchaseService"
PurchaseService.Dependencies = {"DataManager", "NotifyService"}

-- [productKey: string] = (player: Player, productKey: string) -> boolean (true = granted, false = retry next session)
local handlers: {[string]: (Player, string) -> boolean} = {}

function PurchaseService:RegisterProduct(productKey: string, handler: (Player, string) -> boolean)
	assert(type(DevProducts[productKey]) == "table", `RegisterProduct: unknown DevProduct key "{productKey}"`)
	
	if handlers[productKey] then
		warn(`PurchaseService: handler already registered for {productKey}, overwriting`)
	end

	handlers[productKey] = handler
end

local function processReceipt(receiptInfo)
	local player = players:GetPlayerByUserId(receiptInfo.PlayerId :: any)

	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local key, def = DevProducts.GetByProductId(receiptInfo.ProductId)

	if not key or not def then
		warn(`PurchaseService: receipt for unknown ProductId {receiptInfo.ProductId}`)
		
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if DataManager:HasReceipt(player, receiptInfo.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local handler = handlers[key]

	if not handler then
		warn(`PurchaseService: no handler registered for {key} (productId {receiptInfo.ProductId})`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- mark the receipt b4 granting: a disconnect mid-grant then re-delivers as already-processed
	-- instead of paying twice. one-time products reject atomically here so a double-buy race can't
	-- grant twice; a failed handler rolls the mark back so retry still works
	local s, status = DataManager:RecordReceipt(player, receiptInfo.PurchaseId, key, def.OneTime):await()

	if not s then
		task.spawn(error, `RecordReceipt failed for {player.Name}/{key}: {tostring(status)}`)
		
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if status == "duplicate" then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	if status == "limit" then
		warn(`PurchaseService: repeat purchase of one-time product {key} by {player.Name}, not granting`)
		
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local s2, granted = pcall(handler, player, key)

	if s2 and granted then
		NotifyService:Send(player, {
			kind = "ok",
			title = "Thank you!",
			text = "Your purchase went through. Enjoy!",
		})

		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	if not s2 then
		task.spawn(error, `PurchaseService handler error for {key}: {tostring(granted)}`)
	end

	if DataService:hasProfile(player) then
		DataManager:UnrecordReceipt(player, receiptInfo.PurchaseId, key):await()
	else
		task.spawn(error, `PurchaseService: {key} for {player.Name} left mid-grant, receipt stays marked`)
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function PurchaseService.Init(self: {Get: (unknown, string) -> unknown})
	DataManager = self:Get("DataManager") :: typeof(require(script.Parent.DataManager))
	NotifyService = self:Get("NotifyService") :: typeof(require(script.Parent.NotifyService))

	Monetization.setProcessReceipt(processReceipt)
end

return PurchaseService