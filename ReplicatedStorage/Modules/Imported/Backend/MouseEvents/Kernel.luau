local Backend = script.Parent.Parent
local Utility = Backend.Parent.Utility

local Signal = require(Utility.Signal)
local Scythe = require(Utility.Scythe)

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Kernel = {}

-- State -----------------------------------------------------------------------

type Subscriber = { enter: any, leave: any }

type Entry = {
	subscribers: { Subscriber },
	listenerScope: any,
	isOver: boolean,
}

local registry: { [GuiObject]: Entry } = {}
local activeTouchPositions: { [InputObject]: Vector2 } = {}
local activeTouches = 0
local inputMode: Enum.UserInputType = UserInputService:GetLastInputType()
local hoverSound: Sound? = nil
local hoveredCount = 0
local lastTouchPoint: Vector2? = nil

-- Helpers ---------------------------------------------------------------------

local function getInset(): Vector2
	return GuiService:GetGuiInset()
end

local function toGuiPoint(position: Vector3 | Vector2): Vector2
	local point = typeof(position) == "Vector3"
		and Vector2.new(position.X, position.Y)
		or position
	return point - getInset()
end

local function recomputeTouchPoint(): Vector2?
	for _, point in activeTouchPositions do
		return point
	end

	return nil
end

local function attachChangeListener(scope: any, instance: Instance, propertyName: string, callback: () -> ())
	Scythe.add(scope, instance:GetPropertyChangedSignal(propertyName):Connect(callback))
end

local function attachAncestrySensitiveListeners(gui: GuiObject, scope: any, callback: () -> ())
	local ancestryScope = Scythe.scope()
	Scythe.add(scope, function()
		Scythe.destroy(ancestryScope)
	end)

	local function rebuild()
		Scythe.destroy(ancestryScope)
		ancestryScope = Scythe.scope()

		local current: Instance? = gui
		while current do
			if current:IsA("GuiObject") then
				attachChangeListener(ancestryScope, current, "Visible", callback)
				attachChangeListener(ancestryScope, current, "ClipsDescendants", callback)
				attachChangeListener(ancestryScope, current, "ZIndex", callback)
				attachChangeListener(ancestryScope, current, "AbsolutePosition", callback)
				attachChangeListener(ancestryScope, current, "AbsoluteSize", callback)
			elseif current:IsA("ScreenGui") then
				attachChangeListener(ancestryScope, current, "Enabled", callback)
				attachChangeListener(ancestryScope, current, "DisplayOrder", callback)
			end

			current = current.Parent
		end
	end

	Scythe.add(scope, gui.AncestryChanged:Connect(function()
		rebuild()
		callback()
	end))

	rebuild()
end

local function updateHoveredCount(wasOver: boolean, nowOver: boolean)
	if wasOver == nowOver then
		return
	end

	if nowOver then
		hoveredCount += 1
	else
		hoveredCount = math.max(0, hoveredCount - 1)
	end
end

-- Gating ----------------------------------------------------------------------

local function canFire(): boolean
	if inputMode == Enum.UserInputType.Touch then
		return activeTouches > 0
	end

	return true
end

-- Geometric checks ------------------------------------------------------------

local function areAncestorsVisible(gui: GuiObject): boolean
	local current: Instance? = gui

	while current do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		elseif current:IsA("ScreenGui") and not current.Enabled then
			return false
		end

		current = current.Parent
	end

	return true
end

local function isPointInClippingHierarchy(gui: GuiObject, point: Vector2): boolean
	local ancestor: Instance? = gui

	while ancestor and ancestor:IsA("GuiObject") do
		if ancestor.ClipsDescendants then
			local pos = ancestor.AbsolutePosition
			local size = ancestor.AbsoluteSize

			if point.X < pos.X or point.X > pos.X + size.X
				or point.Y < pos.Y or point.Y > pos.Y + size.Y then
				return false
			end
		end

		ancestor = ancestor.Parent
	end

	return true
end

local function isInBounds(gui: GuiObject, point: Vector2): boolean
	local pos = gui.AbsolutePosition
	local size = gui.AbsoluteSize

	return point.X >= pos.X and point.X <= pos.X + size.X
		and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
end

local function isTopmost(gui: GuiObject, point: Vector2): boolean
	local list = playerGui:GetGuiObjectsAtPosition(point.X, point.Y)
	if #list == 0 then
		return true
	end

	for _, obj in list do
		if obj == gui or obj:IsDescendantOf(gui) then
			return true
		end

		if obj.Active then
			return false
		end
	end

	return false
end

local MOUSE_INPUT_TYPES = {
	[Enum.UserInputType.MouseMovement] = true,
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.MouseButton2] = true,
	[Enum.UserInputType.MouseButton3] = true,
	[Enum.UserInputType.MouseWheel] = true,
}

local function getPointerPos(): Vector2?
	if inputMode == Enum.UserInputType.Touch then
		return lastTouchPoint
	end

	if MOUSE_INPUT_TYPES[inputMode] then
		return toGuiPoint(UserInputService:GetMouseLocation())
	end

	return nil
end

function Kernel.isOver(gui: GuiObject): boolean
	if not gui:FindFirstAncestorWhichIsA("ScreenGui") then return false end
	if not areAncestorsVisible(gui) then return false end

	local point = getPointerPos()
	if not point then return false end
	if not isInBounds(gui, point) then return false end
	if not isPointInClippingHierarchy(gui, point) then return false end
	if not isTopmost(gui, point) then return false end
	return true
end

-- Recheck ---------------------------------------------------------------------

local function recheckGui(gui: GuiObject)
	local entry = registry[gui]
	if not entry then return end

	local wasOver = entry.isOver
	local nowOver = canFire() and Kernel.isOver(gui)

	if nowOver == wasOver then return end

	entry.isOver = nowOver
	updateHoveredCount(wasOver, nowOver)

	local snapshot = table.clone(entry.subscribers)

	for i, sub in snapshot do
		if i > 1 then
			local stillOver = canFire() and Kernel.isOver(gui)
			if stillOver ~= nowOver then
				break
			end
		end

		local signal = if nowOver then sub.enter else sub.leave
		if getmetatable(signal) then
			signal:Fire()
		end
	end

	if nowOver then
		Kernel.playHoverSound()
	end
end

function Kernel.recheckAll()
	local snapshot = {}

	for gui in registry do
		table.insert(snapshot, gui)
	end

	for _, gui in snapshot do
		recheckGui(gui)
	end
end

-- Registration ----------------------------------------------------------------

function Kernel.subscribe(gui: GuiObject): Subscriber
	local entry = registry[gui]
	if not entry then
		entry = {
			subscribers = {},
			listenerScope = Scythe.scope(),
			isOver = false,
		}
		registry[gui] = entry

		Scythe.add(entry.listenerScope, gui:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			recheckGui(gui)
		end))

		Scythe.add(entry.listenerScope, gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			recheckGui(gui)
		end))

		Scythe.add(entry.listenerScope, gui:GetPropertyChangedSignal("Visible"):Connect(function()
			recheckGui(gui)
		end))

		Scythe.add(entry.listenerScope, gui:GetPropertyChangedSignal("Active"):Connect(function()
			Kernel.recheckAll()
		end))

		Scythe.add(entry.listenerScope, gui:GetPropertyChangedSignal("ZIndex"):Connect(function()
			Kernel.recheckAll()
		end))

		attachAncestrySensitiveListeners(gui, entry.listenerScope, function()
			recheckGui(gui)
		end)

		Scythe.add(entry.listenerScope, function()
			if entry.isOver then
				updateHoveredCount(true, false)
				entry.isOver = false

				for _, sub in entry.subscribers do
					if getmetatable(sub.leave) then
						sub.leave:Fire()
					end
				end
			end

			for _, sub in entry.subscribers do
				sub.enter:Destroy()
				sub.leave:Destroy()
			end
			table.clear(entry.subscribers)
			if registry[gui] == entry then
				registry[gui] = nil
			end
		end)

		Scythe.attachToInstance(entry.listenerScope, gui)
	end

	local sub: Subscriber = {
		enter = Signal(),
		leave = Signal(),
	}

	table.insert(entry.subscribers, sub)
	recheckGui(gui)

	return sub
end

function Kernel.unsubscribe(gui: GuiObject, sub: Subscriber)
	local entry = registry[gui]
	if not entry then return end

	local idx = table.find(entry.subscribers, sub)
	if not idx then return end

	table.remove(entry.subscribers, idx)
	sub.enter:Destroy()
	sub.leave:Destroy()

	if #entry.subscribers == 0 then
		Scythe.destroy(entry.listenerScope)
	end
end

-- Sound -----------------------------------------------------------------------

function Kernel.useSound(sound: Sound?)
	hoverSound = sound
end

function Kernel.playHoverSound()
	local sound = hoverSound
	if not sound then return end

	task.spawn(function()
		local clone = sound:Clone()
		clone.Parent = SoundService

		if not clone.IsLoaded then
			local deadline = os.clock() + 3
			while clone.Parent and not clone.IsLoaded and os.clock() < deadline do
				task.wait()
			end
		end

		if clone.Parent and clone.IsLoaded then
			clone:Play()
			Debris:AddItem(clone, math.max(clone.TimeLength, 5))
		else
			if clone.Parent then
				clone:Destroy()
			end
		end
	end)
end

-- Input listeners -------------------------------------------------------------

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		Kernel.recheckAll()
	elseif input.UserInputType == Enum.UserInputType.Touch then
		-- toGuiPoint may be wrong for touch, see Known Limitations
		activeTouchPositions[input] = toGuiPoint(input.Position)
		lastTouchPoint = activeTouchPositions[input]
		Kernel.recheckAll()
	end
end)

UserInputService.TouchStarted:Connect(function(input)
	activeTouches += 1
	-- toGuiPoint may be wrong for touch, see Known Limitations
	activeTouchPositions[input] = toGuiPoint(input.Position)
	lastTouchPoint = activeTouchPositions[input]
	Kernel.recheckAll()
end)

UserInputService.TouchEnded:Connect(function(input)
	activeTouches = math.max(0, activeTouches - 1)
	activeTouchPositions[input] = nil

	lastTouchPoint = recomputeTouchPoint()

	Kernel.recheckAll()
end)

UserInputService.TouchTapInWorld:Connect(function()
	Kernel.recheckAll()
end)

UserInputService.LastInputTypeChanged:Connect(function(t)
	inputMode = t
	Kernel.recheckAll()
end)

RunService.RenderStepped:Connect(function()
	if hoveredCount > 0 then
		Kernel.recheckAll()
	end
end)

--[[
	Known Limitations:

	- docs say finger poke "knows about" screen edge border. me not know if this mean need subtract border (like rock mouse) or if already in true math place on glowing hand-rectangle (mobile). right now, cave drawing subtracts border. if finger poke miss target on hand-rectangle, smash `toGuiPoint` rock to dust in finger paths

	- many screen edges: this cave drawing uses one big edge border (`GuiService:GetGuiInset()`) for all math. if different screens have different edge rules (None, DeviceSafeInsets, etc.), true math places will fight and not match. to make good fire, me would need to find edge border for every single screen alone
]]

return Kernel