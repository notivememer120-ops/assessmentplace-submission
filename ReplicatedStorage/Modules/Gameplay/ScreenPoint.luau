--!strict
local players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ts = game:GetService("TweenService")
local rep = game:GetService("ReplicatedStorage")

local Scythe = require(rep.Modules.Imported.Utility.Scythe)
local WaitFor = require(rep.Modules.Gameplay.WaitFor)

local player = players.LocalPlayer :: Player

local maskColor = Color3.new(0, 0, 0)
local maskTransparency = 0.55
local maskZIndex = 1000
local cutoutPadding = 12
local overscan = 250
local jumpThresholdPx = 4
local hideDuration = 0.2
local arrowZOffset = 2
local arrowMargin = 14
local arrowHoverPixels = 10
local arrowHoverDuration = 1.1
local arrowShowDuration = 0.22
local arrowHideDuration = 0.12

local hideInfo = TweenInfo.new(hideDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local arrowPopInfo = TweenInfo.new(arrowShowDuration, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local arrowHoverInfo = TweenInfo.new(arrowHoverDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local arrowFadeInfo = TweenInfo.new(arrowHideDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local ScreenPoint = {}

type Hole = {left: number, top: number, width: number, height: number}

type Edges = {l: number, t: number, r: number, b: number}

type Options = {bottomExtend: number?, arrowOnly: boolean?, shrink: number?}

local screenGui: ScreenGui
local anchor: GuiObject
local maskTemplate: Frame
local maskPool: {Frame} = {}
local maskHideTweens: {[Frame]: Tween} = {}
local arrow: GuiObject?
local arrowPool: {GuiObject} = {}
local arrowTweens: {[number]: Tween} = {}
local arrowShown: {[number]: boolean} = {}
local activeScope: Scythe.Scope?
local currentTargets: {GuiObject}?
local lastBounds: {number}?
local visible = false

local function getMask(i: number): Frame
	local m = maskPool[i]

	if not m then
		m = maskTemplate:Clone()
		m.Name = `Mask{i}`
		m.BorderSizePixel = 0
		m.BackgroundColor3 = maskColor
		m.BackgroundTransparency = 1
		m.ZIndex = maskZIndex
		m.Active = true
		m.Visible = false
		m.Parent = screenGui
		maskPool[i] = m
	end

	return m
end

local function ensureRefs()
	if screenGui then return end
	
	local pg = WaitFor:get(player, "PlayerGui")

	screenGui = WaitFor:get(pg, "PointOnScreen") :: ScreenGui
	anchor = WaitFor:get(screenGui, "__Anchor") :: GuiObject
	maskTemplate = WaitFor:get(screenGui, "MaskTemplate") :: Frame

	arrow = screenGui:FindFirstChild("Arrow") :: GuiObject?
	
	if arrow then
		if not arrow:FindFirstChildOfClass("UIScale") then
			local sc = Instance.new("UIScale")
			sc.Parent = arrow
		end

		arrow.AnchorPoint = Vector2.new(0.5, 0.5)
		arrow.ZIndex = maskZIndex + arrowZOffset
		arrow.Visible = false
		arrowPool[1] = arrow
	end
end

local function holesOf(targets: {GuiObject}, bottomExtend: number?, shrink: number?): {Hole}
	if not shrink then
		shrink = 1
	end

	local factor = shrink :: number
	local origin = anchor.AbsolutePosition
	local holes: {Hole} = {}

	for _, t in targets do
		local pos = t.AbsolutePosition
		local size = t.AbsoluteSize
		-- opt-in shrink hugs the hole around the target's center, scale-relative
		local w = size.X * factor
		local h = size.Y * factor
		local height = h + cutoutPadding * 2

		table.insert(holes, {
			left = pos.X - origin.X + (size.X - w) / 2 - cutoutPadding,
			top = pos.Y - origin.Y + (size.Y - h) / 2 - cutoutPadding,
			width = w + cutoutPadding * 2,
			height = height * (1 + (bottomExtend or 0)),
		})
	end

	return holes
end

local function unionOf(holes: {Hole}): (number, number, number, number)
	local minL = math.huge
	local minT = math.huge
	local maxR = -math.huge
	local maxB = -math.huge

	for _, h in holes do
		minL = math.min(minL, h.left)
		minT = math.min(minT, h.top)
		maxR = math.max(maxR, h.left + h.width)
		maxB = math.max(maxB, h.top + h.height)
	end

	return minL, minT, maxR - minL, maxB - minT
end

local function darkRects(holes: {Hole}, viewW: number, viewH: number): {{number}}
	local x0 = -overscan
	local y0 = -overscan
	local x1 = viewW + overscan
	local y1 = viewH + overscan

	local hs: {Edges} = {}
	
	for _, h in holes do
		table.insert(hs, {
			l = math.floor(h.left),
			t = math.floor(h.top),
			r = math.ceil(h.left + h.width),
			b = math.ceil(h.top + h.height),
		})
	end
	
	table.sort(hs, function(a: Edges, b: Edges) return a.l < b.l end)

	local rects: {{number}} = {}
	local cursorX = x0

	for _, h in hs do
		if h.l > cursorX then
			table.insert(rects, {cursorX, y0, h.l - cursorX, y1 - y0})
		end
		
		if h.t > y0 then
			table.insert(rects, {h.l, y0, h.r - h.l, h.t - y0})
		end
		
		if h.b < y1 then
			table.insert(rects, {h.l, h.b, h.r - h.l, y1 - h.b})
		end
		
		cursorX = math.max(cursorX, h.r)
	end

	if cursorX < x1 then
		table.insert(rects, {cursorX, y0, x1 - cursorX, y1 - y0})
	end

	return rects
end

local function positionMasks(rects: {{number}})
	for i, r in rects do
		local m = getMask(i)

		-- a Set inside hideDuration of a Hide has that fade-out tween still running; w/out
		-- the cancel it overrides this write every frame and parks the mask fully transparent
		local hideTw = maskHideTweens[m]

		if hideTw then
			hideTw:Cancel()

			maskHideTweens[m] = nil
		end

		m.Position = UDim2.fromOffset(r[1], r[2])
		m.Size = UDim2.fromOffset(r[3], r[4])
		m.BackgroundTransparency = maskTransparency
		m.Visible = true
	end

	for i = #rects + 1, #maskPool do
		maskPool[i].Visible = false
	end
end

local function pickSide(left: number, top: number, width: number, height: number): string
	local view = (workspace.CurrentCamera :: Camera).ViewportSize
	
	local sides = {
		{name = "right", area = math.max(0, view.X - (left + width)) * view.Y},
		{name = "left", area = math.max(0, left) * view.Y},
		{name = "top", area = math.max(0, top) * view.X},
		{name = "bottom", area = math.max(0, view.Y - (top + height)) * view.X},
	}
	
	table.sort(sides, function(a: {name: string, area: number}, b: {name: string, area: number}) return a.area > b.area end)
	return sides[1].name
end

local function getArrow(i: number): GuiObject
	if i == 1 then
		return arrow :: GuiObject
	end

	local a = arrowPool[i]
	
	if not a then
		a = (arrow :: GuiObject):Clone()
		a.Name = `Arrow{i}`
		a.AnchorPoint = Vector2.new(0.5, 0.5)
		a.ZIndex = maskZIndex + arrowZOffset
		a.Visible = false
		a.Parent = screenGui
		arrowPool[i] = a
	end

	return a
end

local function placeArrowAt(i: number, left: number, top: number, width: number, height: number)
	local a = getArrow(i)
	local scale = a:FindFirstChildOfClass("UIScale")
	local side = pickSide(left, top, width, height)
	local cx = left + width * 0.5
	local cy = top + height * 0.5

	-- never AbsoluteSize here: the pop UIScale parks at 0 between shows and zeroes it,
	-- which drops the margin math and buries the arrow inside the cutout - derive the
	-- layout size from the parent and the Size property instead
	local parentSize = screenGui.AbsoluteSize
	local halfX = math.max(1, (parentSize.X * a.Size.X.Scale + a.Size.X.Offset) * 0.5)
	local halfY = math.max(1, (parentSize.Y * a.Size.Y.Scale + a.Size.Y.Offset) * 0.5)

	local ax, ay, rot, dx, dy
	
	if side == "right" then
		ax, ay, rot, dx, dy = left + width + arrowMargin + halfX, cy, -90, -1, 0
	elseif side == "left" then
		ax, ay, rot, dx, dy = left - (arrowMargin + halfX), cy, 90, 1, 0
	elseif side == "top" then
		ax, ay, rot, dx, dy = cx, top - (arrowMargin + halfY), 180, 0, 1
	else
		ax, ay, rot, dx, dy = cx, top + height + arrowMargin + halfY, 0, 0, -1
	end

	if arrowTweens[i] then
		arrowTweens[i]:Cancel()
	end

	a.Rotation = rot
	a.Visible = true

	-- the 0-reset pop only plays on a fresh show; re-placements while the target is
	-- still animating (modal springs, dock slides) glide to full scale instead of
	-- strobing the pop over and over
	if scale then
		if not arrowShown[i] then
			scale.Scale = 0
		end

		ts:Create(scale, arrowPopInfo, {Scale = 1}):Play()
	end

	arrowShown[i] = true

	local p1 = UDim2.fromOffset(ax + dx * arrowHoverPixels, ay + dy * arrowHoverPixels)
	local p2 = UDim2.fromOffset(ax - dx * arrowHoverPixels, ay - dy * arrowHoverPixels)
	
	a.Position = p1
	arrowTweens[i] = ts:Create(a, arrowHoverInfo, {Position = p2})

	arrowTweens[i]:Play()
end

local function placeArrows(holes: {Hole})
	if not arrow then
		return
	end

	for i, h in holes do
		placeArrowAt(i, h.left, h.top, h.width, h.height)
	end

	for i = #holes + 1, #arrowPool do
		if arrowTweens[i] then
			arrowTweens[i]:Cancel()

			arrowTweens[i] = nil
		end
		
		arrowPool[i].Visible = false
	end
end

local function hideMasks()
	for _, m in maskPool do
		m.Visible = false
	end
end

function ScreenPoint.Set(target: GuiObject | {GuiObject}, opts: Options?)
	ensureRefs()

	if activeScope then Scythe.destroy(activeScope) end

	local scope = Scythe.scope()

	activeScope = scope

	local prevTargets = currentTargets
	local targets: {GuiObject}

	if typeof(target) == "Instance" then
		targets = {target :: GuiObject}
	else
		targets = target :: {GuiObject}
	end

	currentTargets = targets

	-- pointing at something NEW earns the entrance pop; retargeting the same thing glides
	local fresh = not prevTargets or #prevTargets ~= #targets

	if not fresh then
		for i, t in targets do
			if (prevTargets :: {GuiObject})[i] ~= t then
				fresh = true

				break
			end
		end
	end

	if fresh then
		table.clear(arrowShown)
	end
	
	local bottomExtend = opts and opts.bottomExtend or 0
	local arrowOnly = opts and opts.arrowOnly
	local shrink = opts and opts.shrink

	for _, t in targets do
		Scythe.connect(scope, t.AncestryChanged, function(_, parent)
			if not parent then ScreenPoint.Hide() end
		end)
	end

	local holes = holesOf(targets, bottomExtend, shrink)
	local l, t, w, h = unionOf(holes)
	
	lastBounds = {l, t, w, h}

	local view = (workspace.CurrentCamera :: Camera).ViewportSize

	if arrowOnly then
		hideMasks()
	else
		positionMasks(darkRects(holes, view.X, view.Y))
	end

	visible = true

	placeArrows(holes)

	local arrowBounds = {l, t, w, h}

	Scythe.connect(scope, RunService.Heartbeat, function()
		if not currentTargets then return end

		for _, inst in currentTargets do
			if not inst.Parent then return end
		end

		local hs = holesOf(currentTargets, bottomExtend, shrink)
		local nl, nt, nw, nh = unionOf(hs)
		local prev = lastBounds

		if prev and nl == prev[1] and nt == prev[2] and nw == prev[3] and nh == prev[4] then
			-- settled: an eased slide tails in under the jump threshold, so the arrow can
			-- strand mid-cutout - snap it once to wherever the target actually stopped
			if arrowBounds[1] ~= nl or arrowBounds[2] ~= nt or arrowBounds[3] ~= nw or arrowBounds[4] ~= nh then
				placeArrows(hs)

				arrowBounds = {nl, nt, nw, nh}
			end

			return
		end

		local bigJump = prev and (
			math.abs(nl - prev[1]) > jumpThresholdPx
			or math.abs(nt - prev[2]) > jumpThresholdPx
			or math.abs(nw - prev[3]) > jumpThresholdPx
			or math.abs(nh - prev[4]) > jumpThresholdPx
		)

		lastBounds = {nl, nt, nw, nh}

		if not arrowOnly then
			local v = (workspace.CurrentCamera :: Camera).ViewportSize

			positionMasks(darkRects(hs, v.X, v.Y))
		end

		if bigJump then
			placeArrows(hs)

			arrowBounds = {nl, nt, nw, nh}
		end
	end)
end

function ScreenPoint.Hide()
	if not visible then return end
	
	visible = false
	currentTargets = nil
	lastBounds = nil

	if activeScope then
		Scythe.destroy(activeScope)

		activeScope = nil
	end

	for i, a in arrowPool do
		if arrowTweens[i] then
			arrowTweens[i]:Cancel()

			arrowTweens[i] = nil
		end

		arrowShown[i] = nil

		local scale = a:FindFirstChildOfClass("UIScale")

		if scale then
			ts:Create(scale, arrowFadeInfo, {Scale = 0}):Play()
		end
	end

	task.delay(arrowHideDuration, function()
		if not visible then
			for _, a in arrowPool do
				a.Visible = false
			end
		end
	end)

	for _, m in maskPool do
		if m.Visible then
			local tw = ts:Create(m, hideInfo, {BackgroundTransparency = 1})

			maskHideTweens[m] = tw

			tw.Completed:Connect(function()
				if maskHideTweens[m] == tw then
					maskHideTweens[m] = nil
				end

				if not visible and m.Parent then m.Visible = false end
			end)

			tw:Play()
		end
	end
end

function ScreenPoint.Clear()
	if activeScope then
		Scythe.destroy(activeScope)

		activeScope = nil
	end
	
	for i, a in arrowPool do
		if arrowTweens[i] then
			arrowTweens[i]:Cancel()

			arrowTweens[i] = nil
		end

		a.Visible = false
		arrowShown[i] = nil

		local scale = a:FindFirstChildOfClass("UIScale")

		if scale then scale.Scale = 0 end
	end
	
	for _, m in maskPool do
		m.Visible = false
		m.BackgroundTransparency = 1
	end
	
	visible = false
	currentTargets = nil
	lastBounds = nil
end

return ScreenPoint