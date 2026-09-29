local shop = require(script.Parent.ShopConfig)

export type Setting = {key: string, title: string, icon: string, group: string?, inverse: boolean?, mode: boolean?, detail: string?}

return {
	robux = utf8.char(0xE002),
	assets = {
		coin = "rbxassetid://76848932237342",
	},
	colors = {
		ink = Color3.fromHex("17282b"),
		panel = Color3.fromHex("252f32"),
		inner = Color3.fromHex("1e282b"),
		line = Color3.fromHex("465155"),
		cream = Color3.fromHex("f0ece0"),
		muted = Color3.fromHex("a1aaa6"),
		amber = Color3.fromHex("edb65f"),
		shadow = Color3.fromHex("101b20"),
	},
	settings = {
		{key = "muteMusic", title = "Music", icon = "music", group = "AUDIO", inverse = true},
		{key = "muteSfx", title = "Sound effects", icon = "volume-2", inverse = true},
		{key = "hideChat", title = "Chat", icon = "message-circle", group = "DISPLAY", inverse = true},
		{key = "showFps", title = "FPS counter", icon = "activity"},
		{key = "showServer", title = "Server region", icon = "globe"},
		{key = "cameraMovement", title = "Camera movement", icon = "camera", group = "CAMERA", detail = "Head bob and movement sway"},
		{key = "sprintToggle", title = "Shift to sprint", icon = "keyboard", group = "CONTROLS", mode = true},
	} :: {Setting},
	categories = {"Items"},
	equipment = {
		{key = "Placeholder", row = "Taser", title = shop.items.Placeholder.title, text = shop.items.Placeholder.description, price = shop.items.Placeholder.price, ready = true},
	},
	skins = {},
	offers = {},
	packs = {},
	copy = {
		saved = "Changes save automatically",
		saving = "Saving changes...",
		unsaved = "Changes have not saved yet. Try again shortly.",
		unavailable = "Coming soon",
		funds = "Not enough coins.",
		ok = "Item added to your inventory.",
		busy = "Please wait a moment.",
		invalid = "Item unavailable.",
		stale = "Please try again.",
		failed = "Couldn't confirm the purchase. Check your inventory.",
		shopFooter = "Buy an item with coins.",
	} :: {[string]: string},
}