--!strict
local rep = game:GetService("ReplicatedStorage")

local CandyUI = require(rep.Modules.Gameplay.CandyUI)

local child = CandyUI.child
local txt = CandyUI.txt
local colors = CandyUI.colors
local candy = CandyUI.candy

local NotifyCard = {}

NotifyCard.kinds = {
	{name = "ok", palette = candy.green, sound = "Success"},
	{name = "err", palette = candy.red, sound = "Negative"},
	{name = "info", palette = candy.blue, sound = "Whoosh"},
	{name = "warn", palette = candy.amber, sound = "Whoosh"},
}

NotifyCard.idByName = {}

for i, v in NotifyCard.kinds do
	NotifyCard.idByName[v.name] = i
end

function NotifyCard.build(parent)
	-- canvas margin keeps the halo shadow inside the group's clip bounds
	local canvas = child(parent, "CanvasGroup", {
		Name = "Announce",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(320 + 160, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
	})

	CandyUI.pad(canvas, 80, 80, 80, 80)

	local scale = child(canvas, "UIScale", {Scale = 1})

	local root, glass = CandyUI.sticker(canvas, {
		Name = "Sticker",
		Width = 320,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
	})

	CandyUI.pad(glass, 20, 18, 18, 18)
	CandyUI.vlist(glass, 9)

	local chip = child(glass, "Frame", {
		Name = "Chip",
		Size = UDim2.fromOffset(56, 56),
		Rotation = -4,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		ZIndex = 3,
	})

	CandyUI.corner(chip, 16)
	CandyUI.candyGrad(chip, candy.blue)

	local glyphs = {
		ok = CandyUI.checkGlyph(chip, 30, 6, colors.white),
		err = CandyUI.crossGlyph(chip, 26, 6, colors.white),
		info = txt(chip, "Info", "i", 30, colors.white, {Size = UDim2.new(1, 0, 1, 0), ZIndex = 4}),
		warn = txt(chip, "Warn", "!", 30, colors.white, {Size = UDim2.new(1, 0, 1, 0), ZIndex = 4}),
	}

	local title = txt(glass, "Title", "", 22, colors.cream, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		LayoutOrder = 2,
		ZIndex = 3,
	})

	local body = txt(glass, "Body", "", 14, colors.cream, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextTransparency = 0.35,
		LayoutOrder = 3,
		ZIndex = 3,
	})

	local count = txt(glass, "Count", "", 30, colors.amber, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		LayoutOrder = 4,
		ZIndex = 3,
	})

	local _, ok = CandyUI.button(glass, {
		Name = "Okay",
		Text = "OKAY",
		Palette = candy.green,
		Size = UDim2.new(1, 0, 0, 44),
		TextSize = 16,
		LayoutOrder = 5,
	})

	return {
		root = canvas,
		sticker = root,
		shadow = root:FindFirstChildOfClass("UIShadow"),
		scale = scale,
		chipGrad = chip:FindFirstChildOfClass("UIGradient"),
		glyphs = glyphs,
		title = title,
		body = body,
		count = count,
		ok = ok,
	}
end

function NotifyCard.setKind(h, kindId: number)
	local def = NotifyCard.kinds[kindId]

	h.chipGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, def.palette.top),
		ColorSequenceKeypoint.new(0.46, def.palette.mid),
		ColorSequenceKeypoint.new(1, def.palette.bot),
	})

	h.shadow.Color = def.palette.top

	for k, v in h.glyphs do
		v.Visible = k == def.name
	end

	return def
end

return NotifyCard