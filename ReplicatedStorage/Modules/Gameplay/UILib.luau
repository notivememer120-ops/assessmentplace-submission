--!strict
local CollectionService = game:GetService("CollectionService")
local players = game:GetService("Players")
local rep = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local ts = game:GetService("TweenService")

local spr = require(rep.Modules.Imported.Backend.spr)
local MouseEvents = require(rep.Modules.Imported.Backend.MouseEvents)
local CashFormat = require(rep.Modules.Gameplay.CashFormat)
local DataService = require(rep.Modules.Imported.Backend.DataService).client
local Lucide = require(rep.Modules.Imported.Frontend.LucideIcons)
local Scythe = require(rep.Modules.Imported.Utility.Scythe)
local Tween = require(rep.Modules.Imported.Backend.Tween)
local whichone = {"BackgroundTransparency", "TextTransparency", "TextStrokeTransparency", "ImageTransparency"}

local UILib = {}

export type Hidden = {screenGuis: {[ScreenGui]: boolean}, guiObjects: {[GuiObject]: boolean}}

local gainFlash = Color3.fromHex("5fe024")
local spendFlash = Color3.fromHex("ff5d5d")

UILib.Lucide = Lucide
UILib.spr = spr
UILib.Hover = MouseEvents.Hover
UILib.Tween = MouseEvents.Tween
UILib.noHideTag = "__NO_HIDE"
UILib.noHideDescendantsTag = "__NO_HIDE_DESCENDANTS"

local function isLiveInstance(inst: Instance): boolean
	return not inst:IsDescendantOf(StarterGui)
end

function UILib.tag(tag: string, timeout: number?): Instance
	timeout = timeout or if RunService:IsStudio() then 5 else 90

	local tagged = CollectionService:GetTagged(tag)

	for _, inst in tagged do
		if isLiveInstance(inst) then
			return inst
		end
	end

	local result: Instance? = nil
	local conn: RBXScriptConnection
	local thread = coroutine.running()

	conn = CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		if not result and isLiveInstance(instance) then
			result = instance

			conn:Disconnect()
			
			if coroutine.status(thread) == "suspended" then
				task.spawn(thread)
			end
		end
	end)

	task.delay(timeout, function()
		if not result then
			conn:Disconnect()

			if coroutine.status(thread) == "suspended" then
				task.spawn(thread)
			end
		end
	end)

	if not result then
		coroutine.yield()
	end

	if not result then
		error(`UILib.tag: "{tag}" not found after {timeout}s`, 2)
	end

	return result
end

function UILib.hover(gui: GuiObject, config: {Multiplier: number?, Damping: number?, Frequency: number?}?)
	MouseEvents.Tween.connectButton(gui, config)

	return function()
		MouseEvents.Tween.disconnect(gui)
	end
end

function UILib.unhover(gui: GuiObject)
	MouseEvents.Tween.disconnect(gui)
end

function UILib.tw(obj: Instance, time: number, props: {[string]: any}, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	if not style then
		style = Enum.EasingStyle.Quad
	end

	if not dir then
		dir = Enum.EasingDirection.Out
	end

	local t = ts:Create(obj, TweenInfo.new(time, style, dir), props)

	t:Play()

	return t
end

function UILib.runFor(duration: number, onStep: (number) -> (), onDone: (() -> ())?): RBXScriptConnection
	local start = os.clock()
	local conn: RBXScriptConnection

	conn = RunService.Heartbeat:Connect(function()
		local a = (os.clock() - start) / duration

		if a >= 1 then
			a = 1
		end

		onStep(a)

		if a >= 1 then
			conn:Disconnect()

			if onDone then
				onDone()
			end
		end
	end)

	return conn
end

function UILib.getOrCreateScale(gui: GuiObject, name: string): UIScale
	local existing = gui:FindFirstChild(name)
	
	if existing and existing:IsA("UIScale") then
		return existing
	end

	local uiScale = Instance.new("UIScale")
	uiScale.Name = name
	uiScale.Scale = 1
	uiScale.Parent = gui
	
	return uiScale
end

function UILib.renderScale(gui: GuiObject): number
	local s = 1
	local node: Instance? = gui

	while node do
		local sc = node:FindFirstChildOfClass("UIScale")
		
		if sc then
			s *= sc.Scale
		end
		
		if node:IsA("LayerCollector") then
			break
		end
		
		node = node.Parent
	end

	return s
end

function UILib.fitScale(collector: GuiBase2d, scale: UIScale, refW: number, refH: number)
	local function apply()
		local sz = collector.AbsoluteSize

		if sz.X < 1 or sz.Y < 1 then
			return
		end

		scale.Scale = math.min(sz.X / refW, sz.Y / refH)
	end

	apply()

	collector:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply)
end

function UILib.bindClick(gui: GuiObject, callback: () -> ()): () -> ()
	gui.Active = true

	local scope = Scythe.scope()
	
	Scythe.attachToInstance(scope, gui)
	
	Scythe.connect(scope, gui.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			callback()
		end
	end)

	return function() Scythe.destroy(scope) end
end

function UILib.click(gui: GuiObject, config: {PopScale: number?, Callback: ((...any) -> ())? }?)
	local cfg: {PopScale: number?, Callback: ((...any) -> ())?} = config or {}
	
	local popScale = cfg.PopScale or 0.92
	local callback = cfg.Callback
	local uiScale = UILib.getOrCreateScale(gui, "_UILibClick")

	return UILib.bindClick(gui, function()
		spr.target(uiScale, 1, 8, {Scale = popScale})

		task.delay(0.06, function()
			if not uiScale or not uiScale.Parent then return end
			
			spr.target(uiScale, 0.7, 5, {Scale = 1})
		end)

		if callback then
			callback()
		end
	end)
end

function UILib.oscillateRotation(
	gui: GuiObject,
	opts: {min: number?, max: number?, period: number?}?): () -> ()
	local options: {min: number?, max: number?, period: number?} = opts or {}
	
	local min = options.min or -2
	local max = options.max or 2
	local period = options.period or 8
	local amp = (max - min) / 2
	local center = (min + max) / 2
	local scope = Scythe.scope()
	
	Scythe.attachToInstance(scope, gui)
	
	Scythe.connect(scope, RunService.RenderStepped, function()
		local phase = -math.cos(2 * math.pi * (os.clock() / period))

		gui.Rotation = center + amp * phase
	end)

	return function() Scythe.destroy(scope) end
end

function UILib.oscillateScale(gui: GuiObject,opts: {min: number?, max: number?, period: number?, scaleName: string?}?): () -> ()
	local options: {min: number?, max: number?, period: number?, scaleName: string?} = opts or {}
	
	local min = options.min or 0.95
	local max = options.max or 1.1
	local period = options.period or 6.4
	local scaleName = options.scaleName or "_Oscillate"
	local amp = (max - min) / 2
	local center = (min + max) / 2
	local uiScale = UILib.getOrCreateScale(gui, scaleName)
	local scope = Scythe.scope()
	
	Scythe.attachToInstance(scope, gui)
	Scythe.connect(scope, RunService.RenderStepped, function()
		local phase = -math.cos(2 * math.pi * (os.clock() / period))

		uiScale.Scale = center + amp * phase
	end)

	return function() Scythe.destroy(scope) end
end

function UILib.formatCash(amount: number | string): string
	return CashFormat.format(amount)
end

function UILib.bindData(label: TextLabel, dataKey: string, formatFn: ((any) -> string)?): () -> ()
	local format = formatFn or function(v)
		return tostring(v or 0)
	end

	local current = DataService:get(dataKey)
	
	label.Text = format(current)

	local conn = DataService:getChangedSignal(dataKey):Connect(function(newVal)
		label.Text = format(newVal)
	end)

	return function()
		conn:Disconnect()
	end
end

function UILib.commaFormat(n: number): string
	local s = tostring(math.floor(n + 0.5))

	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

function UILib.bindDataAnimated(label: TextLabel, dataKey: string, formatFn: ((number) -> string)?): () -> ()
	if not formatFn then
		formatFn = UILib.commaFormat
	end

	local format = formatFn :: (number) -> string
	local restColor = label.TextColor3
	local shown = DataService:get(dataKey) or 0

	label.Text = format(shown)

	local token = 0

	local conn = DataService:getChangedSignal(dataKey):Connect(function(newVal)
		newVal = newVal or 0
		
		local from = shown
		shown = newVal

		if newVal == from then
			return
		end

		token += 1

		local my = token

		label.TextColor3 = newVal > from and gainFlash or spendFlash

		task.spawn(function()
			local dur = 0.6
			local t0 = os.clock()

			while true do
				local a = math.min(1, (os.clock() - t0) / dur)
				local eased = 1 - (1 - a) ^ 3

				if token ~= my then
					return
				end

				label.Text = format(from + (newVal - from) * eased)
				
				if a >= 1 then
					break
				end

				task.wait(0.045)
			end

			task.wait(0.25)

			if token == my then
				label.TextColor3 = restColor
			end
		end)
	end)

	return function()
		conn:Disconnect()
	end
end

local function hasNoHideAncestor(inst: Instance, root: Instance): boolean
	local cur: Instance? = inst

	while cur and cur ~= root do
		if CollectionService:HasTag(cur, UILib.noHideTag) then return true end

		cur = cur.Parent
	end

	return false
end

local function hasSkipDescendantsAncestor(inst: Instance, root: Instance): boolean
	local cur = inst.Parent

	while cur and cur ~= root do
		if CollectionService:HasTag(cur, UILib.noHideDescendantsTag) then return true end

		cur = cur.Parent
	end

	return false
end

local function hasNoHideDescendant(inst: Instance): boolean
	if CollectionService:HasTag(inst, UILib.noHideTag) then return true end
	
	for _, d in inst:GetDescendants() do
		if CollectionService:HasTag(d, UILib.noHideTag) then return true end
	end

	return false
end

function UILib.hideScope(root: Instance): Hidden
	local screenGuis: {[ScreenGui]: boolean} = {}
	local guiObjects: {[GuiObject]: boolean} = {}

	for _, child in root:GetChildren() do
		if child:IsA("ScreenGui") and not hasNoHideDescendant(child) then
			screenGuis[child] = child.Enabled
			child.Enabled = false
		end
	end

	for _, inst in root:GetDescendants() do
		if not (inst:IsA("GuiObject") and inst.Visible) then continue end

		if hasSkipDescendantsAncestor(inst, root) then continue end

		if CollectionService:HasTag(inst, UILib.noHideDescendantsTag) then
			guiObjects[inst] = true
			inst.Visible = false
			
			continue
		end

		if not hasNoHideAncestor(inst, root) and not hasNoHideDescendant(inst) then
			guiObjects[inst] = true
			inst.Visible = false
		end
	end

	return {screenGuis = screenGuis, guiObjects = guiObjects}
end

function UILib.restoreScope(handle: Hidden?)
	if not handle then return end

	for gui, enabled in handle.screenGuis do
		if gui.Parent then
			gui.Enabled = enabled
		end
	end

	for inst in handle.guiObjects do
		if inst.Parent then
			inst.Visible = true
		end
	end
end

function UILib.saveTransparencies(root: Instance): {[Instance]: {[string]: number}}
	local saved: {[Instance]: {[string]: number}} = {}
	local all = root:GetDescendants()

	table.insert(all, root)

	for _, inst in all do
		local props: {[string]: number} = {}

		for _, prop in whichone do
			local s, val = pcall(function() return (inst :: any)[prop] end)

			if s and type(val) == "number" then
				props[prop] = val
			end
		end

		if next(props) then
			saved[inst] = props
		end
	end

	return saved
end

function UILib.setAllTransparent(root: Instance)
	local all = root:GetDescendants()

	table.insert(all, root)

	for _, inst in all do
		for _, prop in whichone do
			pcall(function() (inst :: any)[prop] = 1 end)
		end
	end
end

function UILib.tweenTransparenciesIn(saved: {[Instance]: {[string]: number}}, duration: number)
	local tweens = {}

	for inst, props in saved do
		if inst.Parent then
			local t = Tween(inst, props, {Time = duration, EasingStyle = "Quad", EasingDirection = "Out"})
			t:Start()

			table.insert(tweens, t)
		end
	end

	return tweens
end

function UILib.setThumbnail(imageLabel: ImageLabel, userId: number)
	userId = math.abs(userId)
	
	task.spawn(function()
		local s, img = pcall(function()
			return players:GetUserThumbnailAsync(userId :: any, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		end)

		imageLabel.Image = s and img or `rbxthumb://type=AvatarHeadShot&id={userId}&w=420&h=420`
	end)
end

return UILib