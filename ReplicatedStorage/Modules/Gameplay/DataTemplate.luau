--!strict

local Types = require(script.Parent.AssessmentTypes)

local template: Types.PlayerData = {
	timesJoined = 0,
	cash = 0,
	bagLevel = 1,
	playtime = 0,
	ownedPasses = {},
	purchasedProducts = {},
	processedReceipts = {},

	items = {Placeholder = 0},

	tutorial = {
		sprintCompleted = false,
	},

	settings = {
		muteMusic = false,
		muteSfx = false,
		hideChat = false,
		showFps = false,
		showServer = false,
		cameraMovement = true,
		sprintToggle = false,
	},
}

return template