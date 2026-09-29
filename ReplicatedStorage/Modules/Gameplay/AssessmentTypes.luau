--!strict

export type Settings = {
	muteMusic: boolean,
	muteSfx: boolean,
	hideChat: boolean,
	showFps: boolean,
	showServer: boolean,
	cameraMovement: boolean,
	sprintToggle: boolean,
}

export type PlayerData = {
	timesJoined: number,
	cash: number,
	bagLevel: number,
	playtime: number,
	ownedPasses: {[string]: boolean},
	purchasedProducts: {[string]: number},
	processedReceipts: {[string]: number | true},
	items: {[string]: number},
	tutorial: {sprintCompleted: boolean},
	settings: Settings,
}

export type PickupResult = "ok" | "missing" | "claimed" | "locked" | "range" | "blocked" | "full" | "inactive" | "busy"

export type UpgradeResult = "ok" | "owned" | "funds" | "inactive" | "busy"

export type EventName = "collect" | "deposit" | "upgrade"

export type EventFields = {[string]: number | string | boolean}

return {}