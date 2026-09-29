local Kernel = require(script.Parent.Kernel)

local Hover = {}

export type HoverHandle = {
	Enter: any,
	Leave: any,
	Destroy: (self: HoverHandle) -> (),
}

function Hover.new(gui: GuiObject): HoverHandle
	local sub = Kernel.subscribe(gui)

	local handle = {
		Enter = sub.enter,
		Leave = sub.leave,
	}

	function handle:Destroy()
		Kernel.unsubscribe(gui, sub)
	end

	return handle
end

function Hover.isOver(gui: GuiObject): boolean
	return Kernel.isOver(gui)
end

function Hover.useSound(sound: Sound?)
	Kernel.useSound(sound)
end

return Hover