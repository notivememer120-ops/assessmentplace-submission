local rep = game:GetService("ReplicatedStorage")

local UIAssets = require(rep.Modules.Configs.UIAssetsConfig)

local white = Color3.new(1, 1, 1)
local stickerSlice = Rect.new(63, 63, 65, 65)

local function hexSet(top, mid, bot, bevel)
	return {
		top = Color3.fromHex(top),
		mid = Color3.fromHex(mid),
		bot = Color3.fromHex(bot),
		bevel = Color3.fromHex(bevel),
	}
end

local CandyUI = {}

CandyUI.font = Font.fromEnum(Enum.Font.FredokaOne)

CandyUI.colors = {
	white = white,
	cream = Color3.fromHex("fdfcf5"),
	ink = Color3.fromHex("06121f"),
	amber = Color3.fromHex("ffd27a"),
	glassTop = Color3.fromHex("1d2638"),
	glassMid = Color3.fromHex("141b28"),
	glassBot = Color3.fromHex("0f141e"),
	stickerBot = Color3.fromHex("eef2f8"),
	scrim = Color3.fromHex("080c14"),
}

CandyUI.candy = {
	green = hexSet("8bea5d", "54c12c", "2f8714", "1f5510"),
	red = hexSet("ff7a5a", "e0442c", "a82414", "6c1409"),
	blue = hexSet("7db4ff", "3f86f0", "2a63c4", "1c3f80"),
	steel = hexSet("8fa3be", "748bab", "5d7396", "3c4d6b"),
	amber = hexSet("f3bd52", "d68f24", "a8640f", "6c3e07"),
	grey = hexSet("6a7d99", "586a87", "46566f", "2c3850"),
	gift = hexSet("ffd98a", "ff9b3d", "e85f17", "8a4a08"),
}

local function make(c, p)
	local o = Instance.new(c)

	for k, v in p do
		o[k] = v
	end

	return o
end

local function child(par, c, p)
	local o = make(c, p)

	o.Parent = par

	return o
end

local function corner(par, r)
	child(par, "UICorner", {CornerRadius = UDim.new(0, r)})
end

local function pad(par, t, r, b, l)
	child(par, "UIPadding", {PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b), PaddingLeft = UDim.new(0, l)})
end

local function vlist(par, gap, align)
	if not align then
		align = Enum.HorizontalAlignment.Center
	end

	return child(par, "UIListLayout", {FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = align, Padding = UDim.new(0, gap), SortOrder = Enum.SortOrder.LayoutOrder})
end

local function hlist(par, gap)
	return child(par, "UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, gap), SortOrder = Enum.SortOrder.LayoutOrder})
end

local function txt(par: Instance, name: string, str: string, size: number, col: Color3, p: {[string]: any}?): TextLabel
	if not p then
		p = {}
	end

	p.Name = name
	p.Text = str
	p.FontFace = CandyUI.font
	p.TextSize = size
	p.TextColor3 = col
	p.BackgroundTransparency = 1

	return child(par, "TextLabel", p)
end

local function candyGrad(par, pal)
	par.BackgroundColor3 = white

	child(par, "UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, pal.top),
			ColorSequenceKeypoint.new(0.46, pal.mid),
			ColorSequenceKeypoint.new(1, pal.bot),
		}),
		Rotation = 90,
	})
end

function CandyUI.shadow(parent, offsetY, blur, transparency, col, spread)
	if not col then
		col = Color3.new(0, 0, 0)
	end

	if not spread then
		spread = 0
	end

	return child(parent, "UIShadow", {
		Offset = UDim2.fromOffset(0, offsetY),
		BlurRadius = UDim.new(0, blur),
		Spread = UDim2.fromOffset(spread, spread),
		Transparency = transparency,
		Color = col,
		ZIndex = -1,
	})
end

-- mirrors the authored shop Buy anatomy: bevel frame poked 6px down, solid face,
-- white gloss wash on the top third (Gloss = false skips it), plain FredokaOne label
function CandyUI.button(parent: Instance, p: {
	Name: string,
	Text: string,
	Palette: {top: Color3, mid: Color3, bot: Color3, bevel: Color3},
	Size: UDim2,
	TextSize: number,
	LayoutOrder: number?,
	Corner: number?,
	Gradient: boolean?,
	Gloss: boolean?,
	Shadow: boolean?,
	Icon: (number | string)?,
	IconSize: number?,
})
	local r = p.Corner
	local pal = p.Palette

	if not r then
		r = 15
	end

	local layoutOrder = p.LayoutOrder

	if not layoutOrder then
		layoutOrder = 0
	end

	local holder = child(parent, "Frame", {
		Name = p.Name,
		Size = p.Size,
		LayoutOrder = layoutOrder,
		BackgroundTransparency = 1,
	})

	local bev = child(holder, "Frame", {
		Name = "Bev",
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.fromOffset(0, 6),
		BackgroundColor3 = pal.bevel,
		BorderSizePixel = 0,
		ZIndex = 0,
	})

	corner(bev, r)

	local btn = child(holder, "TextButton", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = pal.mid,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 1,
	})

	corner(btn, r)

	if p.Gradient then
		candyGrad(btn, pal)
	end

	local gloss = child(btn, "Frame", {
		Name = "Gloss",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = white,
		BorderSizePixel = 0,
		ZIndex = 2,
	})

	corner(gloss, r)

	child(gloss, "UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(0.35, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})

	if p.Gloss == false then
		gloss.Visible = false
	end

	if p.Shadow then
		CandyUI.shadow(btn, 8, 16, 0.5)
	end

	local label

	if p.Icon then
		local row = child(btn, "Frame", {
			Name = "Row",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			ZIndex = 3,
		})

		hlist(row, 7)

		local iconSize = p.IconSize

		if not iconSize then
			iconSize = 18
		end

		child(row, "ImageLabel", {
			Name = "Icon",
			Size = UDim2.fromOffset(iconSize, iconSize),
			BackgroundTransparency = 1,
			Image = `rbxassetid://{p.Icon}`,
			ZIndex = 3,
			LayoutOrder = 1,
		})

		label = txt(row, "Lbl", p.Text, p.TextSize, CandyUI.colors.white, {
			AutomaticSize = Enum.AutomaticSize.XY,
			ZIndex = 3,
			LayoutOrder = 2,
		})
	else
		label = txt(btn, "Lbl", p.Text, p.TextSize, CandyUI.colors.white, {
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 3,
		})
	end

	return holder, btn, label
end

function CandyUI.sticker(parent, p)
	local rotation = p.Rotation

	if not rotation then
		rotation = 0
	end

	local shadowCol = p.ShadowColor

	if not shadowCol then
		shadowCol = Color3.fromHex("4aa3ff")
	end

	local root = child(parent, "ImageLabel", {
		Name = p.Name,
		AnchorPoint = p.AnchorPoint,
		Position = p.Position,
		Size = UDim2.fromOffset(p.Width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Rotation = rotation,
		BackgroundTransparency = if UIAssets.stickerRing == "" then 0 else 1,
		BackgroundColor3 = white,
		BorderSizePixel = 0,
		Image = UIAssets.stickerRing,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = stickerSlice,
		SliceScale = 0.5,
		ZIndex = 2,
	})

	CandyUI.shadow(root, 0, 30, 0.55, shadowCol, 6)
	pad(root, 4, 4, 4, 4)

	local glass = child(root, "ImageLabel", {
		Name = "Glass",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = if UIAssets.stickerFill == "" then 0 else 1,
		BackgroundColor3 = white,
		BorderSizePixel = 0,
		Image = UIAssets.stickerFill,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = stickerSlice,
		SliceScale = 0.5,
		ZIndex = 2,
	})

	child(glass, "UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, CandyUI.colors.glassTop),
			ColorSequenceKeypoint.new(0.58, CandyUI.colors.glassMid),
			ColorSequenceKeypoint.new(1, CandyUI.colors.glassBot),
		}),
		Rotation = 90,
	})

	return root, glass
end

function CandyUI.scrim(parent)
	return child(parent, "Frame", {
		Name = "Scrim",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = CandyUI.colors.scrim,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		Active = true,
	})
end

function CandyUI.crossGlyph(parent, size, thickness, col)
	local holder = child(parent, "Frame", {
		Name = "Cross",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = parent.ZIndex + 1,
	})

	for _, v in {45, -45} do
		local bar = child(holder, "Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 0, 0, thickness),
			Rotation = v,
			BackgroundColor3 = col or white,
			BorderSizePixel = 0,
			ZIndex = holder.ZIndex,
		})

		corner(bar, math.ceil(thickness / 2))
	end

	return holder
end

function CandyUI.checkGlyph(parent, size, thickness, col)
	local holder = child(parent, "Frame", {
		Name = "Check",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = parent.ZIndex + 1,
	})

	local short = child(holder, "Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.28, 0.62),
		Size = UDim2.new(0.42, 0, 0, thickness),
		Rotation = 45,
		BackgroundColor3 = col or white,
		BorderSizePixel = 0,
		ZIndex = holder.ZIndex,
	})

	corner(short, math.ceil(thickness / 2))

	local long = child(holder, "Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.62, 0.48),
		Size = UDim2.new(0.72, 0, 0, thickness),
		Rotation = -50,
		BackgroundColor3 = col or white,
		BorderSizePixel = 0,
		ZIndex = holder.ZIndex,
	})

	corner(long, math.ceil(thickness / 2))

	return holder
end

CandyUI.make = make
CandyUI.child = child
CandyUI.corner = corner
CandyUI.pad = pad
CandyUI.vlist = vlist
CandyUI.hlist = hlist
CandyUI.txt = txt
CandyUI.candyGrad = candyGrad

return CandyUI