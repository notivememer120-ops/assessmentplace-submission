--!strict

local rep = game:GetService("ReplicatedStorage")
local config = require(rep.Modules.Configs.AssessmentConfig)
local queries = require(rep.Modules.Packets.BagPackets).queries
local Types = require(rep.Modules.Gameplay.AssessmentTypes)
local BagRules = require(rep.Modules.Gameplay.BagRules)
local PointInPart = require(rep.Modules.Gameplay.PointInPart)
local RateGate = require(rep.Modules.Gameplay.RateGate)
local Timer = require(rep.Modules.Imported.Backend.Timer)
local Scythe = require(rep.Modules.Imported.Utility.Scythe)
local DataManager = require(script.Parent.DataManager)
local Analytics = require(script.Parent.AnalyticsService)

local bags: {[Player]: number} = {}
local gate = RateGate.new(config.upgradeInterval)
local scope: number
local depositZone: BasePart

local BagService = {}
BagService.__slittttName = "BagService"
BagService.Dependencies = {"DataManager", "AnalyticsService"}

function BagService:CanCollect(player: Player): Types.PickupResult
	local count = bags[player]

	if count == nil then return "inactive" end

	if count >= BagRules.capacity(DataManager:GetBagLevel(player)) then return "full" end

	return "ok"
end

function BagService:Add(player: Player)
	bags[player] += 1

	player:SetAttribute("BagCount", bags[player])
end

function BagService:Deposit(player: Player): number
	local count = bags[player]

	if count == nil or count == 0 then return 0 end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")

	if not hum or hum.Health <= 0 or not hum.RootPart or not PointInPart(depositZone, hum.RootPart.Position) then return 0 end

	bags[player] = 0

	local coins = DataManager:DepositBag(player, count)

	player:SetAttribute("BagCount", 0)
	Analytics:Track("deposit", player, {count = count, coins = coins})
	return coins
end

function BagService:Upgrade(player: Player): Types.UpgradeResult
	if bags[player] == nil then return "inactive" end

	if gate:tooFast(player) then return "busy" end

	local result: Types.UpgradeResult = DataManager:UpgradeBag(player)

	if result == "ok" then
		player:SetAttribute("BagLevel", 2)
		player:SetAttribute("BagCapacity", BagRules.capacity(2))
		Analytics:Track("upgrade", player, {level = 2, capacity = BagRules.capacity(2), cost = config.upgradePrice})
	end

	return result
end

function BagService:Init()
	scope = Scythe.scope()
	depositZone = workspace.Map.Assessment.DepositZone

	Scythe.add(scope, queries.Upgrade.listen(function(_, player): string return self:Upgrade(player :: Player) end))

	local timer = Scythe.add(scope, Timer.new(config.depositInterval))

	Scythe.connect(scope, timer.Tick, function()
		for player, count in bags do
			if count > 0 then self:Deposit(player) end
		end
	end)

	timer:Start()
end

function BagService:OnPlayerJoined(player: Player)
	bags[player] = 0

	local level = DataManager:GetBagLevel(player)

	player:SetAttribute("BagLevel", level)
	player:SetAttribute("BagCapacity", BagRules.capacity(level))
	player:SetAttribute("BagCount", 0)
end

function BagService:OnPlayerRemoving(player: Player)
	bags[player] = nil

	gate:forget(player)
end

function BagService:Destroy()
	Scythe.destroy(scope)

	for player in bags do self:OnPlayerRemoving(player) end
end

return BagService