--!strict

local config = require(script.Parent.Parent.Configs.AssessmentConfig)

local BagRules = {}

function BagRules.capacity(level: number): number
	return if level >= 2 then config.upgradedCapacity else config.bagCapacity
end

function BagRules.deposit(count: number): number
	return count * config.coinValue
end

function BagRules.upgrade(level: number, cash: number): "ok" | "owned" | "funds"
	if level >= 2 then return "owned" end

	if cash < config.upgradePrice then return "funds" end

	return "ok"
end

return BagRules