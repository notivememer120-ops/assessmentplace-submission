--!strict

local rep = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DataService = require(rep.Modules.Imported.Backend.DataService).server
local DataTemplate = require(rep.Modules.Gameplay.DataTemplate)

local Promise = require(rep.Modules.Imported.Backend.Promise)
local Sift = require(rep.Modules.Imported.Backend.Sift)
local Signal = require(rep.Modules.Imported.Utility.Signal)
local StatFields = require(rep.Modules.Configs.StatFieldsConfig)
local ShopConfig = require(rep.Modules.Configs.ShopConfig)
local DataStoreKeys = require(ServerStorage.Modules.DataStoreKeys)
local Types = require(rep.Modules.Gameplay.AssessmentTypes)
local BagRules = require(rep.Modules.Gameplay.BagRules)
local assessment = require(rep.Modules.Configs.AssessmentConfig)

type StatPromise = Promise.Promise

type StatMethod = (unknown, Player, number) -> StatPromise

type NullMethod = (unknown, Player) -> StatPromise

type StatMethods = {
	AddTimesJoined: StatMethod,
	AddPlaytime: StatMethod,
	AddCash: StatMethod,
	DeductTimesJoined: StatMethod,
	DeductPlaytime: StatMethod,
	DeductCash: StatMethod,
	SetTimesJoined: StatMethod,
	SetPlaytime: StatMethod,
	SetCash: StatMethod,
	NullTimesJoined: NullMethod,
	NullPlaytime: NullMethod,
	NullCash: NullMethod,
}

local sessionStartTimes: {[Player]: number} = {}
local DataManager = {}
DataManager.__slittttName = "DataManager"

DataManager.StatChanged = Signal() :: Signal.Signal<Player, string, number>
DataManager.DataWiped = Signal() :: Signal.Signal<number>

-- age prunes first (roblox stops re-delivering unacked receipts long b4 30 days); the count
-- cap is a profile-size backstop that should never realistically bite
local receiptCap = 500
local receiptMaxAge = 30 * 86400

function DataManager:Init()
	DataService:init({
		template = DataTemplate,
		profileStoreIndex = DataStoreKeys.PlayerProfile,
	})

	function DataService:onPlayerInit(player: Player, data: {[string]: unknown})
		sessionStartTimes[player] = os.time()

		local reconciled = Sift.Dictionary.mergeDeep(DataTemplate, data) :: {[string]: unknown}

		for i, v in reconciled do
			data[i] = v
		end
	end

	DataService:addPlayerRemovingCallback(function(player: Player, data: Types.PlayerData)
		local startTime = sessionStartTimes[player]

		if startTime then
			data.playtime += (os.time() - startTime)
			sessionStartTimes[player] = nil

			DataManager.StatChanged:Fire(player, "playtime", data.playtime)
		end
	end)
end

function DataManager:AwaitProfile(player: Player)
	DataService:waitForData(player)
end

function DataManager:GetSprintTutorialCompleted(player: Player): boolean
	return DataService:get(player, {"tutorial", "sprintCompleted"}) == true
end

function DataManager:SetSprintTutorialCompleted(player: Player)
	DataService:set(player, {"tutorial", "sprintCompleted"}, true)
end

function DataManager:BuyItem(player: Player, key: string): string
	local item = ShopConfig.Get(key)

	if not item then return "invalid" end

	local cash = DataService:get(player, "cash")

	if cash < item.price then return "funds" end

	local items = table.clone(DataService:get(player, "items"))

	items[key] = (items[key] or 0) + 1

	DataService:setMany(player, {cash = cash - item.price, items = items})
	self.StatChanged:Fire(player, "cash", cash - item.price)
	return "ok"
end

function DataManager:GetPlayerData(player: Player): Types.PlayerData
	return DataService:get(player)
end

function DataManager:GetBagLevel(player: Player): number
	return DataManager:GetPlayerData(player).bagLevel
end

function DataManager.DepositBag(self: typeof(DataManager), player: Player, count: number): number
	local coins = BagRules.deposit(count)
	local data: Types.PlayerData = DataManager:GetPlayerData(player)
	local cash = data.cash + coins

	DataService:set(player, "cash", cash)
	self.StatChanged:Fire(player, "cash", cash)
	return coins
end

function DataManager.UpgradeBag(self: typeof(DataManager), player: Player): "ok" | "owned" | "funds"
	local data: Types.PlayerData = DataManager:GetPlayerData(player)
	local result: "ok" | "owned" | "funds" = BagRules.upgrade(data.bagLevel, data.cash)

	if result ~= "ok" then return result end

	local cash = data.cash - assessment.upgradePrice

	DataService:setMany(player, {cash = cash, bagLevel = 2})
	self.StatChanged:Fire(player, "cash", cash)
	return "ok"
end

function DataManager:GetSessionStart(player: Player)
	return sessionStartTimes[player]
end

local statMethods = (DataManager :: unknown) :: {[string]: StatMethod | NullMethod}

for k, v in StatFields.Fields do
	statMethods[`Add{k}`] = function(_self, player: Player, amount: number): Promise.Promise
		return Promise.new(function(resolve)
			DataService:waitForData(player)

			local newVal = DataService:update(player, v, function(current)
				return (current or 0) + amount
			end)

			DataManager.StatChanged:Fire(player, v, newVal)
			
			resolve(newVal)
		end)
	end

	statMethods[`Deduct{k}`] = function(_self, player: Player, amount: number): Promise.Promise
		return Promise.new(function(resolve)
			DataService:waitForData(player)

			local newVal = DataService:update(player, v, function(current)
				return math.max((current or 0) - amount, 0)
			end)

			DataManager.StatChanged:Fire(player, v, newVal)
			
			resolve(newVal)
		end)
	end

	statMethods[`Set{k}`] = function(_self, player: Player, value: number): Promise.Promise
		return Promise.new(function(resolve)
			DataService:waitForData(player)
			DataService:set(player, v, value)
			DataManager.StatChanged:Fire(player, v, value)
			
			resolve(value)
		end)
	end

	statMethods[`Null{k}`] = function(_self, player: Player): Promise.Promise
		return Promise.new(function(resolve)
			DataService:waitForData(player)
			DataService:set(player, v, 0)
			DataManager.StatChanged:Fire(player, v, 0)
			
			resolve(0)
		end)
	end
end

function DataManager:GetCash(player: Player): Promise.Promise
	return Promise.new(function(resolve)
		local data = DataService:waitForData(player)
		
		resolve(data:get("cash"))
	end)
end

function DataManager:GetStat(player: Player, key: "cash" | "playtime" | "timesJoined"): number
	DataService:waitForData(player)
	
	return DataService:get(player, key)
end

function DataManager:WipeData(player: Player)
	DataManager.DataWiped:Fire(player.UserId)
	DataService:resetData(player)
end

function DataManager:SetSettings(player: Player, settings: Types.Settings): Promise.Promise
	return Promise.new(function(resolve)
		DataService:waitForData(player)
		DataService:set(player, "settings", settings)

		resolve(settings)
	end)
end

function DataManager:AddOwnedPass(player: Player, passKey: string): Promise.Promise
	return Promise.new(function(resolve)
		DataService:waitForData(player)
		DataService:set(player, {"ownedPasses", passKey}, true)
		
		resolve()
	end)
end

function DataManager:HasOwnedPass(player: Player, passKey: string): boolean
	DataService:waitForData(player)
	
	return DataService:get(player, {"ownedPasses", passKey}) == true
end

function DataManager:HasReceipt(player: Player, purchaseId: string): boolean
	DataService:waitForData(player)
	
	return DataService:get(player, {"processedReceipts", purchaseId}) ~= nil
end

function DataManager:RecordReceipt(player: Player, purchaseId: string, productKey: string, oneTime: boolean?): Promise.Promise
	return Promise.new(function(resolve)
		DataService:waitForData(player)

		if DataService:get(player, {"processedReceipts", purchaseId}) ~= nil then
			resolve("duplicate")
			return
		end

		if oneTime and (DataService:get(player, {"purchasedProducts", productKey}) or 0) > 0 then
			resolve("limit")
			return
		end

		DataService:update(player, "processedReceipts", function(prev: {[string]: number | true})
			local now = os.time()

			prev[purchaseId] = now

			local keys = {}

			for k, t in prev do
				if type(t) ~= "number" or now - t > receiptMaxAge then
					prev[k] = nil
				else
					table.insert(keys, k)
				end
			end

			if #keys > receiptCap then
				table.sort(keys, function(a, b)
					return (prev[a] :: number) < (prev[b] :: number)
				end)

				for i = 1, #keys - receiptCap do
					prev[keys[i]] = nil
				end
			end

			return prev
		end)
		
		DataService:update(player, "purchasedProducts", function(prev)
			prev[productKey] = (prev[productKey] or 0) + 1
			
			return prev
		end)
		
		resolve("recorded")
	end)
end

function DataManager:UnrecordReceipt(player: Player, purchaseId: string, productKey: string): Promise.Promise
	return Promise.new(function(resolve)
		DataService:waitForData(player)

		DataService:update(player, "processedReceipts", function(prev)
			prev[purchaseId] = nil
			
			return prev
		end)
		
		DataService:update(player, "purchasedProducts", function(prev)
			local n = (prev[productKey] or 0) - 1

			if n > 0 then
				prev[productKey] = n
			else
				prev[productKey] = nil
			end
			
			return prev
		end)
		
		resolve()
	end)
end

function DataManager:RemoveOwnedPass(player: Player, passKey: string): Promise.Promise
	return Promise.new(function(resolve)
		DataService:waitForData(player)

		DataService:update(player, "ownedPasses", function(owned)
			owned[passKey] = nil
			
			return owned
		end)

		resolve()
	end)
end

return DataManager :: typeof(DataManager) & StatMethods