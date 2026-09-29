--!strict
local cas = game:GetService("ContextActionService")
local rep = game:GetService("ReplicatedStorage")
local uis = game:GetService("UserInputService")
local player = game:GetService("Players").LocalPlayer :: Player

local LoadingScreenEvents = require(rep.Modules.Gameplay.LoadingScreenEvents)
local MovementPackets = require(rep.Modules.Packets.MovementPackets)
local SettingsTopbar = require(script.Parent.SettingsTopbar)
local ModalGuard = require(rep.Modules.Gameplay.ModalGuard)
local Scythe = require(rep.Modules.Imported.Utility.Scythe)

local SprintIntent = MovementPackets.packets.SprintIntent

local actionName = "sprint"
local held = false

local SprintController = {}
SprintController.__slittttName = "SprintController"
SprintController.Dependencies = {"SettingsTopbar"}

type Controller = typeof(SprintController) & {
	_scope: Scythe.Scope,
	_touchScope: Scythe.Scope,
	_touchFrame: GuiObject?,
	_jump: GuiButton?,
}

local function send(running: boolean)
	if held == running then
		return
	end

	held = running

	SprintIntent.send({running = running})
end

local function onSprint(_: string, state: Enum.UserInputState, input: InputObject)
	if state == Enum.UserInputState.Cancel then
		send(false)
		return Enum.ContextActionResult.Sink
	end

	if not LoadingScreenEvents.HasHidden or ModalGuard.anyOpen() or uis:GetFocusedTextBox() then
		send(false)
		return Enum.ContextActionResult.Sink
	end

	local toggle = input.KeyCode == Enum.KeyCode.LeftShift and SettingsTopbar:GetValue("sprintToggle")

	if state == Enum.UserInputState.Begin then
		send(if toggle then not held else true)
	elseif state == Enum.UserInputState.End and not toggle then
		send(false)
	end

	return Enum.ContextActionResult.Sink
end

function SprintController:cancel()
	send(false)
end

function SprintController._styleTouch(self: Controller)
	local button = cas:GetButton(actionName) :: GuiButton?

	if not button then return end

	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Size = UDim2.fromOffset(56, 56)

	local frame = button.Parent :: GuiObject
	local touchGui = player.PlayerGui:FindFirstChild("TouchGui")
	local jump = touchGui and touchGui:FindFirstChild("JumpButton", true) :: GuiButton?

	if self._touchFrame ~= frame or self._jump ~= jump then
		Scythe.clean(self._touchScope)

		self._touchFrame = frame
		self._jump = jump

		for _, name in {"AbsoluteSize", "AbsolutePosition"} do
			Scythe.connect(self._touchScope, frame:GetPropertyChangedSignal(name), function() self:_styleTouch() end)

			if jump then
				Scythe.connect(self._touchScope, jump:GetPropertyChangedSignal(name), function() self:_styleTouch() end)
			end
		end
	end

	if jump then
		local position = jump.AbsolutePosition + Vector2.new(jump.AbsoluteSize.X / 2, -12) - frame.AbsolutePosition

		cas:SetPosition(actionName, UDim2.fromOffset(position.X, position.Y))
	else
		cas:SetPosition(actionName, UDim2.new(1, -40, 0, -12))
	end
end

function SprintController.Init(self: Controller)
	self._scope = Scythe.scope()
	self._touchScope = Scythe.extend(self._scope)

	Scythe.connect(self._scope, SettingsTopbar.Changed, function(key)
		if key == "sprintToggle" then send(false) end
	end)

	Scythe.connect(self._scope, player.CharacterRemoving, function() send(false) end)
	Scythe.connect(self._scope, player:GetAttributeChangedSignal("sprintLocked"), function()
		if player:GetAttribute("sprintLocked") then send(false) end
	end)

	cas:BindActionAtPriority(actionName, onSprint, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	cas:SetTitle(actionName, "RUN")

	Scythe.connect(self._scope, uis.WindowFocusReleased, function()
		send(false)
	end)
	Scythe.connect(self._scope, player.PlayerGui.DescendantAdded, function(inst)
		if inst.Name == "JumpButton" or inst.Name == "ContextActionButton" then
			Scythe.add(self._scope, task.defer(function() self:_styleTouch() end))
		end
	end)

	Scythe.connect(self._scope, uis:GetPropertyChangedSignal("TouchEnabled"), function() self:_styleTouch() end)

	self:_styleTouch()
end

function SprintController.Destroy(self: Controller)
	send(false)
	Scythe.destroy(self._scope)

	cas:UnbindAction(actionName)
end

return SprintController :: Controller