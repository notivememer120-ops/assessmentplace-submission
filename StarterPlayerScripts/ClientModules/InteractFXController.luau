local players = game:GetService("Players")
local rep = game:GetService("ReplicatedStorage")
local ts = game:GetService("TweenService")
local uis = game:GetService("UserInputService")

local UISfx = require(rep.Modules.Gameplay.UISfx)
local player = players.LocalPlayer :: Player

local quadOut = TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local backOut = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local fastOut = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local closeHoverInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local closeDownInfo = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local closeUpInfo = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local closeHoverScale = 1.07

local rippleInfo = TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

type Controller = {
	__slittttName: string,
	_rippleGui: ScreenGui,
	brighten: (Controller, GuiObject, number, boolean?) -> (),
	darken: (Controller, GuiObject, number) -> (),
	wireCandy: (Controller, GuiButton, number) -> (),
	wireCard: (Controller, GuiObject, boolean?) -> (),
	liftHover: (Controller, GuiObject, number, boolean?) -> (),
	wireClose: (Controller, GuiButton) -> (),
	_ripple: (Controller, number, number) -> (),
	Init: (Controller) -> (),
}

local InteractFXController = {} :: Controller
InteractFXController.__slittttName = "InteractFXController"

local function clickInput(io: InputObject): boolean
	return io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch
end

local function hoverOK(el: GuiObject): boolean
	local p: Instance = el

	while p.Parent and not p.Parent:IsA("ScreenGui") do
		p = p.Parent
	end

	for _, m in p:GetChildren() do
		if m:IsA("GuiObject") and m.Visible and m:FindFirstChild("FadeWrap") and not el:IsDescendantOf(m) then
			return false
		end
	end

	return true
end

local function getScale(el: GuiObject): UIScale
	local s = el:FindFirstChild("HoverScale") :: UIScale?

	if not s then
		s = Instance.new("UIScale")
		s.Name = "HoverScale"
		s.Parent = el
	end

	return s
end

function InteractFXController:brighten(el: GuiObject, amt: number, soft: boolean?)
	if el:FindFirstChildOfClass("UIListLayout") then
		el.MouseEnter:Connect(function()
			if not hoverOK(el) or el:GetAttribute("_fxOff") then
				return

			end

			UISfx.play(soft and "Hover1" or "Hover2")

			local r = (el:GetAttribute("_hoverRest") or el:GetAttribute("_restT") or el.BackgroundTransparency) :: number

			el:SetAttribute("_restT", r)
			
			if r < 0.05 then
				local rc = (el:GetAttribute("_restC") or el.BackgroundColor3) :: Color3

				el:SetAttribute("_restC", rc)
				ts:Create(el, quadOut, {BackgroundColor3 = rc:Lerp(Color3.new(1, 1, 1), amt)}):Play()
			elseif r < 1 then
				ts:Create(el, quadOut, {BackgroundTransparency = math.max(0, r - 0.12)}):Play()
			end
		end)

		el.MouseLeave:Connect(function()
			local r = el:GetAttribute("_hoverRest") or el:GetAttribute("_restT")

			if r then
				ts:Create(el, quadOut, {BackgroundTransparency = r}):Play()
			end

			local rc = el:GetAttribute("_restC")

			if rc then
				ts:Create(el, quadOut, {BackgroundColor3 = rc}):Play()
			end
		end)

	else

		local hi = el:FindFirstChild("HoverHi") :: Frame?

		if not hi then
			hi = Instance.new("Frame")
			hi.Name = "HoverHi"
			hi.Size = UDim2.fromScale(1, 1)
			hi.BackgroundColor3 = Color3.new(1, 1, 1)
			hi.BackgroundTransparency = 1
			hi.BorderSizePixel = 0
			hi.ZIndex = 40

			local uc = el:FindFirstChildOfClass("UICorner")

			if uc then
				uc:Clone().Parent = hi
			end

			hi.Parent = el
		end

		local function heal()
			local fxr = el:GetAttribute("_fx_BackgroundTransparency") :: number?

			if fxr ~= nil and math.abs(el.BackgroundTransparency - fxr) > 0.02 then
				el.BackgroundTransparency = fxr
			end
		end

		el.MouseEnter:Connect(function()
			if not hoverOK(el) or el:GetAttribute("_fxOff") then
				return
			end

			UISfx.play(soft and "Hover1" or "Hover2")
			heal()
			
			ts:Create(hi, quadOut, {BackgroundTransparency = 1 - amt}):Play()
		end)
		
		el.MouseLeave:Connect(function()
			heal()

			ts:Create(hi, quadOut, {BackgroundTransparency = 1}):Play()
		end)
	end
end

function InteractFXController:darken(el: GuiObject, amt: number)
	if el:FindFirstChildOfClass("UIListLayout") then
		el.MouseEnter:Connect(function()
			if not hoverOK(el) then
				return

			end

			UISfx.play("Hover2")

			local r = (el:GetAttribute("_hoverRest") or el:GetAttribute("_restT") or el.BackgroundTransparency) :: number

			el:SetAttribute("_restT", r)
			
			if r < 1 then
				ts:Create(el, quadOut, {BackgroundTransparency = math.min(1, r + amt)}):Play()
			end
		end)

		el.MouseLeave:Connect(function()
			local r = el:GetAttribute("_hoverRest") or el:GetAttribute("_restT")

			if r then
				ts:Create(el, quadOut, {BackgroundTransparency = r}):Play()
			end
		end)
	else
		local hi = el:FindFirstChild("HoverDim") :: Frame?

		if not hi then
			hi = Instance.new("Frame")
			hi.Name = "HoverDim"
			hi.Size = UDim2.fromScale(1, 1)
			hi.BackgroundColor3 = Color3.new(0, 0, 0)
			hi.BackgroundTransparency = 1
			hi.BorderSizePixel = 0
			hi.ZIndex = 40

			local uc = el:FindFirstChildOfClass("UICorner")

			if uc then
				uc:Clone().Parent = hi
			end

			hi.Parent = el
		end

		el.MouseEnter:Connect(function()
			if not hoverOK(el) then
				return

			end

			UISfx.play("Hover2")

			ts:Create(hi, quadOut, {BackgroundTransparency = 1 - amt}):Play()
		end)
		
		el.MouseLeave:Connect(function()
			ts:Create(hi, quadOut, {BackgroundTransparency = 1}):Play()
		end)
	end

	el.InputBegan:Connect(function(io)
		if clickInput(io) and hoverOK(el) then
			UISfx.play("Click")
		end
	end)
end

function InteractFXController:wireCandy(btn: GuiButton, amt: number)
	local hs = btn:FindFirstChild("HoverScale")

	if hs then
		hs:Destroy()
	end

	local face = (btn:FindFirstChild("Face") or btn) :: GuiObject
	local bevel = (btn:FindFirstChild("Bev") or btn:FindFirstChild("Bevel")) :: GuiObject?

	if not bevel and btn.Parent then
		bevel = (btn.Parent:FindFirstChild("Bev") or btn.Parent:FindFirstChild("BevelGreen") or btn.Parent:FindFirstChild("BevelAccent")) :: GuiObject?
	end

	local poke = bevel and (bevel.Position.Y.Offset - face.Position.Y.Offset) or 4
	local pressPx = math.clamp(poke - 2, 2, math.max(2, poke))
	local restPos = face.Position

	self:brighten(face, amt)

	btn.InputBegan:Connect(function(io)
		if clickInput(io) and hoverOK(btn) and not btn:GetAttribute("_fxOff") then
			UISfx.play("Click")

			ts:Create(face, fastOut, {Position = restPos + UDim2.fromOffset(0, pressPx)}):Play()
		end
	end)

	btn.InputEnded:Connect(function(io)
		if clickInput(io) then
			ts:Create(face, backOut, {Position = restPos}):Play()
		end
	end)
end

function InteractFXController:wireCard(el: GuiObject, btn: boolean?)
	local s = getScale(el)
	local sh = el:FindFirstChildOfClass("UIShadow")
	local rb: UDim
	local ro: UDim2
	local rt: number

	if sh then
		rb = sh.BlurRadius
		ro = sh.Offset
		rt = sh.Transparency
	end

	local hovering = false
	local pressed = false
	
	local function upd()
		ts:Create(s, pressed and fastOut or backOut, {Scale = (pressed and 0.985) or (hovering and 1.03) or 1}):Play()

		if sh then
			if hovering and not pressed then
				ts:Create(sh, quadOut, {BlurRadius = UDim.new(0, math.round(rb.Offset * 1.5)), Offset = UDim2.new(0, 0, 0, ro.Y.Offset + 6), Transparency = math.max(0, rt - 0.12)}):Play()
			else
				ts:Create(sh, quadOut, {BlurRadius = rb, Offset = ro, Transparency = rt}):Play()
			end
		end
	end

	el.MouseEnter:Connect(function()
		if not hoverOK(el) then
			return

		end

		UISfx.play(btn and "Hover2" or "Hover1")

		hovering = true

		upd()
	end)
	
	el.MouseLeave:Connect(function()
		hovering = false
		pressed = false

		upd()
	end)
	
	el.InputBegan:Connect(function(io)
		if clickInput(io) then
			pressed = true

			upd()
		end
	end)

	el.InputEnded:Connect(function(io)
		if clickInput(io) then
			pressed = false

			upd()
		end
	end)
end

function InteractFXController:liftHover(el: GuiObject, amt: number, btn: boolean?)
	local s = getScale(el)

	el.MouseEnter:Connect(function()
		if not hoverOK(el) then
			return

		end

		UISfx.play(btn and "Hover2" or "Hover1")

		ts:Create(s, quadOut, {Scale = amt}):Play()
	end)
	
	el.MouseLeave:Connect(function()
		ts:Create(s, quadOut, {Scale = 1}):Play()
	end)
end

function InteractFXController:wireClose(close: GuiButton)
	local visual = close:FindFirstChild("Visual")

	if not visual then
		return
	end

	local face = visual:FindFirstChild("Face")
	local fx = visual:FindFirstChild("FX")

	if not face or not fx then
		return
	end

	local pressPx = (close:GetAttribute("PressPx") or 4) :: number
	local hovering = false
	local pressed = false
	
	local function faceUp()
		ts:Create(face, closeUpInfo, {Position = UDim2.new(0, 0, 0, 0), Rotation = 0}):Play()
	end

	close.MouseEnter:Connect(function()
		hovering = true

		UISfx.play("Hover2")

		if not pressed then
			ts:Create(fx, closeHoverInfo, {Scale = closeHoverScale}):Play()
		end
	end)

	close.MouseLeave:Connect(function()
		hovering = false

		ts:Create(fx, closeHoverInfo, {Scale = 1}):Play()

		if not pressed then
			faceUp()
		end
	end)

	close.InputBegan:Connect(function(io)
		if not clickInput(io) then
			return
		end

		UISfx.play("Click")

		pressed = true

		ts:Create(face, closeDownInfo, {Position = UDim2.new(0, 0, 0, pressPx), Rotation = 3}):Play()
		ts:Create(fx, closeDownInfo, {Scale = 1}):Play()
	end)
	
	close.InputEnded:Connect(function(io)
		if not clickInput(io) then
			return
		end

		pressed = false

		faceUp()

		ts:Create(fx, closeHoverInfo, {Scale = hovering and closeHoverScale or 1}):Play()
	end)
end

function InteractFXController:_ripple(x: number, y: number)
	local c = Instance.new("Frame")
	c.BackgroundTransparency = 1
	c.AnchorPoint = Vector2.new(0.5, 0.5)
	c.Position = UDim2.fromOffset(x, y)
	c.Size = UDim2.fromOffset(10, 10)
	c.BorderSizePixel = 0

	local uc = Instance.new("UICorner")
	uc.CornerRadius = UDim.new(1, 0)
	uc.Parent = c

	local st = Instance.new("UIStroke")
	st.Color = Color3.new(1, 1, 1)
	st.Thickness = 2.5
	st.Transparency = 0.25
	st.Parent = c

	c.Parent = self._rippleGui

	ts:Create(c, rippleInfo, {Size = UDim2.fromOffset(52, 52)}):Play()
	
	local t = ts:Create(st, rippleInfo, {Transparency = 1, Thickness = 1})
	
	t.Completed:Once(function()
		c:Destroy()
	end)
	
	t:Play()
end

function InteractFXController:Init()
	local sg = Instance.new("ScreenGui")
	sg.Name = "ClickRipples"
	sg.IgnoreGuiInset = true
	sg.DisplayOrder = 1000
	sg.ResetOnSpawn = false
	sg.Parent = player.PlayerGui

	self._rippleGui = sg

	uis.InputBegan:Connect(function(io)
		if clickInput(io) then
			local m = uis:GetMouseLocation()
			
			self:_ripple(m.X, m.Y)
		end
	end)
end

return InteractFXController