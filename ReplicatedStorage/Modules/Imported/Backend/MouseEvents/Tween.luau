local Backend = script.Parent.Parent
local Utility = Backend.Parent.Utility

local Scythe = require(Utility.Scythe)
local spr = require(Backend.spr)

local Hover = require(script.Parent.Hover)

local Tween = {}

export type Options = {
	Multiplier: number?,
	Damping: number?,
	Frequency: number?,
}

local DEFAULT_MULTIPLIER = 1.1
local DEFAULT_DAMPING = 1
local DEFAULT_FREQUENCY = 4

local connections: { [GuiObject]: any } = {}

function Tween.connectButton(button: GuiObject, options: Options?)
	Tween.disconnect(button)

	local opts = options or {}
	local mult = opts.Multiplier or DEFAULT_MULTIPLIER
	local damping = opts.Damping or DEFAULT_DAMPING
	local frequency = opts.Frequency or DEFAULT_FREQUENCY

	local scope = Scythe.scope()
	connections[button] = scope

	Scythe.add(scope, function()
		if connections[button] == scope then
			connections[button] = nil
		end
	end)

	local ownedScale = false
	local uiScale = button:FindFirstChild("_MouseEventsHover")
	if uiScale and uiScale:IsA("UIScale") then
		spr.stop(uiScale)
		uiScale.Scale = 1
	else
		uiScale = Instance.new("UIScale")
		uiScale.Name = "_MouseEventsHover"
		uiScale.Scale = 1
		uiScale.Parent = button
		ownedScale = true
	end

	if ownedScale then
		Scythe.add(scope, uiScale)
	else
		Scythe.add(scope, function()
			spr.stop(uiScale)
			uiScale.Scale = 1
		end)
	end

	local handle = Hover.new(button)
	Scythe.add(scope, handle)

	Scythe.add(scope, handle.Enter:Connect(function()
		spr.target(uiScale, damping, frequency, { Scale = mult })
	end))

	Scythe.add(scope, handle.Leave:Connect(function()
		spr.target(uiScale, damping, frequency, { Scale = 1 })
	end))

	Scythe.add(scope, function()
		spr.stop(uiScale)
	end)

	Scythe.attachToInstance(scope, button)
end

function Tween.connectAll(buttons: { GuiObject }, options: Options?)
	for _, button in buttons do
		Tween.connectButton(button, options)
	end
end

function Tween.disconnect(button: GuiObject)
	local scope = connections[button]
	if not scope then return end
	connections[button] = nil
	Scythe.destroy(scope)
end

function Tween.disconnectAll()
	local snapshot = {}
	for button, scope in connections do
		snapshot[button] = scope
	end
	table.clear(connections)
	for _, scope in snapshot do
		Scythe.destroy(scope)
	end
end

return Tween