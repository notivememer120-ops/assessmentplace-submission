local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local inputDtc = {}
inputDtc.__index = inputDtc

export type InputType = "Mouse" | "Touch" | "Gamepad"
export type inputDtc = {
	_guiObject: GuiObject,
	_connections: { RBXScriptConnection },
	_hoverStartCallbacks: { (inputType: InputType) -> () },
	_hoverEndCallbacks: { (inputType: InputType) -> () },
	_activatedCallbacks: { (inputType: InputType) -> () },
	_isHovered: boolean,
	_isSelected: boolean,
	_destroyed: boolean,

	onHoverStart: (self: inputDtc, callback: (InputType) -> ()) -> () -> (),
	onHoverEnd: (self: inputDtc, callback: (InputType) -> ()) -> () -> (),
	onActivated: (self: inputDtc, callback: (InputType) -> ()) -> () -> (),
	isHovered: (self: inputDtc) -> boolean,
	destroy: (self: inputDtc) -> (),
}

function inputDtc.new(guiObject: GuiObject): inputDtc
	assert(
		typeof(guiObject) == "Instance" and guiObject:IsA("GuiObject"),
		"inputDtc expects a GuiObject"
	)

	local self = setmetatable({
		_guiObject = guiObject,
		_connections = {},
		_hoverStartCallbacks = {},
		_hoverEndCallbacks = {},
		_activatedCallbacks = {},
		_isHovered = false,
		_isSelected = false,
		_destroyed = false,
	}, inputDtc)

	self:_bind()
	return self :: any
end

function inputDtc._connect(self: inputDtc, signal: RBXScriptSignal, handler: (...any) -> ())
	table.insert(self._connections, signal:Connect(handler))
end

function inputDtc._subscribe(
	self: inputDtc,
	list: { (inputType: InputType) -> () },
	callback: (inputType: InputType) -> ()
): () -> ()
	if self._destroyed then
		warn("inputDtc: callback registered on a destroyed instance")
		return function() end
	end

	table.insert(list, callback)

	local disconnected = false
	return function()
		if disconnected or self._destroyed then
			return
		end
		disconnected = true

		local index = table.find(list, callback)
		if index then
			table.remove(list, index)
		end
	end
end

function inputDtc.onHoverStart(self: inputDtc, callback: (inputType: InputType) -> ()): () -> ()
	return self:_subscribe(self._hoverStartCallbacks, callback)
end

function inputDtc.onHoverEnd(self: inputDtc, callback: (inputType: InputType) -> ()): () -> ()
	return self:_subscribe(self._hoverEndCallbacks, callback)
end

function inputDtc.onActivated(self: inputDtc, callback: (inputType: InputType) -> ()): () -> ()
	return self:_subscribe(self._activatedCallbacks, callback)
end

function inputDtc.isHovered(self: inputDtc): boolean
	if self._destroyed then
		return false
	end
	return self._isHovered or self._isSelected
end

function inputDtc.destroy(self: inputDtc)
	if self._destroyed then
		return
	end

	self._destroyed = true

	for _, connection in self._connections do
		connection:Disconnect()
	end

	table.clear(self._connections)
	table.clear(self._hoverStartCallbacks)
	table.clear(self._hoverEndCallbacks)
	table.clear(self._activatedCallbacks)
end

function inputDtc._fireCallbacks(
	self: inputDtc,
	list: { (inputType: InputType) -> () },
	inputType: InputType
)
	if self._destroyed then
		return
	end

	for _, callback in ipairs(table.clone(list)) do
		task.defer(callback, inputType)
	end
end

function inputDtc._classifyInput(self: inputDtc, inputObject: InputObject): InputType?
	local inputType = inputObject.UserInputType

	if inputType == Enum.UserInputType.Touch then
		return "Touch"
	end

	if inputType == Enum.UserInputType.MouseMovement
		or inputType == Enum.UserInputType.MouseButton1
		or inputType == Enum.UserInputType.MouseButton2
		or inputType == Enum.UserInputType.MouseButton3 then
		return "Mouse"
	end

	if inputType.Name:find("Gamepad") then
		return "Gamepad"
	end

	return nil
end

function inputDtc._bind(self: inputDtc)
	local guiObject = self._guiObject
	local topLeftInset = select(1, GuiService:GetGuiInset())

	local function shouldIgnoreInset(): boolean
		local current = guiObject
		
		while current do
			if current:IsA("ScreenGui") then
				return current.IgnoreGuiInset
			end
			
			current = current.Parent
		end
		
		return false
	end

	local function toGuiPosition(position: Vector2): Vector2
		if shouldIgnoreInset() then
			return position
		else
			return position - topLeftInset
		end
	end

	local function inputPositionToGuiPosition(inputObject: InputObject): Vector2
		return toGuiPosition(Vector2.new(inputObject.Position.X, inputObject.Position.Y))
	end

	local lastMousePosition = toGuiPosition(UserInputService:GetMouseLocation())
	local lastMouseHover = false

	local function isPointInside(position: Vector2): boolean
		if self._destroyed or not guiObject.Visible then
			return false
		end

		local pos = guiObject.AbsolutePosition
		local size = guiObject.AbsoluteSize

		if size.X <= 0 or size.Y <= 0 then
			return false
		end

		return position.X >= pos.X
			and position.X < pos.X + size.X
			and position.Y >= pos.Y
			and position.Y < pos.Y + size.Y
	end

	local function updateMouseHover()
		if self._destroyed then
			return
		end

		local inside = isPointInside(lastMousePosition)
		if inside == lastMouseHover then
			return
		end

		lastMouseHover = inside
		self._isHovered = inside

		if inside then
			self:_fireCallbacks(self._hoverStartCallbacks, "Mouse")
		else
			self:_fireCallbacks(self._hoverEndCallbacks, "Mouse")
		end
	end

	self:_connect(UserInputService.InputChanged, function(inputObject: InputObject)
		if self._destroyed then
			return
		end

		if inputObject.UserInputType == Enum.UserInputType.MouseMovement then
			lastMousePosition = inputPositionToGuiPosition(inputObject)
			updateMouseHover()
		end
	end)

	self:_connect(RunService.RenderStepped, function()
		updateMouseHover()
	end)

	self:_connect(guiObject.SelectionGained, function()
		self._isSelected = true
		self:_fireCallbacks(self._hoverStartCallbacks, "Gamepad")
	end)

	self:_connect(guiObject.SelectionLost, function()
		self._isSelected = false
		self:_fireCallbacks(self._hoverEndCallbacks, "Gamepad")
	end)

	if guiObject:IsA("GuiButton") then
		self:_connect(guiObject.Activated, function(inputObject: InputObject)
			local classified = self:_classifyInput(inputObject)
			if classified then
				self:_fireCallbacks(self._activatedCallbacks, classified)
			end
		end)
	else
		local activePressInputs: { [InputObject]: InputType } = {}

		self:_connect(guiObject.InputBegan, function(inputObject: InputObject)
			local classified = self:_classifyInput(inputObject)
			if classified == "Mouse" or classified == "Touch" then
				activePressInputs[inputObject] = classified
			end
		end)

		self:_connect(UserInputService.InputEnded, function(inputObject: InputObject)
			local classified = activePressInputs[inputObject]
			if not classified then
				return
			end

			activePressInputs[inputObject] = nil

			local releasePosition = inputPositionToGuiPosition(inputObject)
			if isPointInside(releasePosition) then
				self:_fireCallbacks(self._activatedCallbacks, classified)
			end
		end)
	end

	self:_connect(guiObject.Destroying, function()
		self:destroy()
	end)

	updateMouseHover()
end

return inputDtc