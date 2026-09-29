--!strict

local analytics = game:GetService("AnalyticsService")
local Types = require(game:GetService("ReplicatedStorage").Modules.Gameplay.AssessmentTypes)

local keys = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}

local fieldsByEvent: {[Types.EventName]: {string}} = {
	collect = {"zone", "id", "total"},
	deposit = {"count", "coins"},
	upgrade = {"level", "capacity", "cost"},
}

local AnalyticsService = {}
AnalyticsService.__slittttName = "AnalyticsService"

function AnalyticsService:Track(name: Types.EventName, player: Player, fields: Types.EventFields)
	local custom: {[string]: string} = {}

	for i, v in fieldsByEvent[name] do
		custom[keys[i]] = `{v}={fields[v]}`
	end

	task.defer(function()
		analytics:LogCustomEvent(player, name, 1, custom)
	end)
end

return AnalyticsService