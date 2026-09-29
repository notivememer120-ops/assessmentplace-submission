--!strict
local players = game:GetService("Players")
local rep = game:GetService("ReplicatedStorage")
local uis = game:GetService("UserInputService")

local UISfx = require(rep.Modules.Gameplay.UISfx)
local getPlatform = require(rep.Modules.Imported.Utility.OSDetector)

local ModalGuard = {}

local closeLatch = 0.12
local tapSlop = 16

local platform = getPlatform()
local touchDevice = uis.TouchEnabled
	or platform == Enum.Platform.IOS
	or platform == Enum.Platform.Android
	or platform == Enum.Platform.UWP
	or platform == Enum.Platform.MetaOS

local modals: {GuiObject} = {}
local lastClose = 0

-- weak keys: cards get destroyed on every grid re-render and must not pile up here
local tapTargets: {[GuiObject]: () -> ()} = setmetatable({}, {__mode = "k"})
local touchWatchOn = false

-- one screen-level watcher for all scroller taps: per-element InputBegan/Ended only
-- see the slice of a swipe crossing that element (8px/10ms reads as a tap), and any
-- per-card gesture listener stalls scroll start while the engine disambiguates tap
-- from pan, which is the "laggy scroll" feel in dense grids
local function ensureTouchWatch()
	if touchWatchOn then
		return
	end

	touchWatchOn = true

	local starts: {[InputObject]: Vector3} = {}

	uis.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.Touch then
			starts[io] = io.Position
		end
	end)

	uis.InputEnded:Connect(function(io)
		local from = starts[io]

		if not from then
			return
		end

		starts[io] = nil

		if math.abs(io.Position.X - from.X) > tapSlop or math.abs(io.Position.Y - from.Y) > tapSlop then
			return
		end

		for _, o in (players.LocalPlayer :: Player).PlayerGui:GetGuiObjectsAtPosition(io.Position.X, io.Position.Y) do
			local handler = tapTargets[o :: GuiObject]

			if handler then
				handler()

				return
			end
		end
	end)
end

-- own Visible isn't enough: a modal left open inside a hidden panel (player switched
-- tabs mid-prompt) would silently block every click in the rest of the UI
local function shown(m: GuiObject): boolean
	local o: Instance? = m

	while o do
		if o:IsA("LayerCollector") then
			return o.Enabled
		end

		if o:IsA("GuiObject") and not o.Visible then
			return false
		end

		o = o.Parent
	end

	return false
end

function ModalGuard.register(modal: GuiObject): () -> ()
	table.insert(modals, modal)

	local registered = true

	return function()
		if not registered then
			return
		end

		registered = false

		table.remove(modals, table.find(modals, modal))
	end
end

function ModalGuard.stampClose()
	lastClose = os.clock()
end

function ModalGuard.anyOpen()
	for _, m in modals do
		if shown(m) then
			return true
		end
	end

	return false
end

function ModalGuard.blocks(el: GuiObject): boolean
	if os.clock() - lastClose < closeLatch then
		return true
	end

	for _, m in modals do
		if shown(m) and not el:IsDescendantOf(m) then
			return true
		end
	end

	return false
end

function ModalGuard.onClick(el: GuiObject, fn: () -> ())
	local function h()
		if ModalGuard.blocks(el) then
			return
		end

		fn()
	end

	-- everything wired here is a button: hover + press cues, press-timed so it collapses with any wireCandy Click
	el.MouseEnter:Connect(function()
		if not ModalGuard.blocks(el) then
			UISfx.play("Hover2")
		end
	end)

	if el:IsA("GuiButton") then
		el.InputBegan:Connect(function(io)
			if (io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch) and not ModalGuard.blocks(el) then
				UISfx.play("Click")
			end
		end)

		el.Activated:Connect(h)

		return
	end

	el.Active = true

	-- only scroller content needs tap-vs-swipe discrimination; everything else keeps
	-- firing the moment it's pressed (release-waiting reads as input lag, and slightly
	-- sloppy taps got eaten as micro-swipes)
	local o = el.Parent

	while o do
		if o:IsA("ScrollingFrame") then
			break
		end

		o = o.Parent
	end

	if not o then
		el.InputBegan:Connect(function(io)
			if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
				if not ModalGuard.blocks(el) then
					UISfx.play("Click")
				end

				h()
			end
		end)

		return
	end

	-- scroller content carries NO touch listeners of its own - taps route through the
	-- screen-level watcher + a point hit-test, so the scroller gets every touch the
	-- instant it lands; mouse commits on press, wheel scrolling never drags
	if touchDevice then
		ensureTouchWatch()

		tapTargets[el] = function()
			if not ModalGuard.blocks(el) then
				UISfx.play("Click")
			end

			h()
		end
	end

	el.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 and io.UserInputState == Enum.UserInputState.Begin then
			if not ModalGuard.blocks(el) then
				UISfx.play("Click")
			end

			h()
		end
	end)
end

function ModalGuard.onClickOutside(scrim: GuiObject, dlg: GuiObject?, fn: () -> ())
	scrim.Active = true
	
	return scrim.InputBegan:Connect(function(io)
		if io.UserInputType ~= Enum.UserInputType.MouseButton1 and io.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		if dlg then
			local p = io.Position
			local dp = dlg.AbsolutePosition
			local ds = dlg.AbsoluteSize
			
			if p.X >= dp.X and p.X <= dp.X + ds.X and p.Y >= dp.Y and p.Y <= dp.Y + ds.Y then
				return
			end
		end

		fn()
	end)
end

return ModalGuard