local runServ = game:GetService("RunService")

local core = require(script.Core)
local Scythe = table.clone(core)

export type Scope = core.Scope

export type Facade = {
	scope: typeof(core.scope),
	addBulk: typeof(core.addBulk),
	remove: typeof(core.remove),
	clean: typeof(core.clean),
	destroy: typeof(core.destroy),
	count: typeof(core.count),
	isAlive: typeof(core.isAlive),
	add: <T>(Scope, T, string?) -> T,
	extend: (Scope) -> Scope,
	connect: (Scope, any, (...any) -> ()) -> any,
	once: (Scope, any, (...any) -> ()) -> any,
	clone: <T>(Scope, T) -> T,
	construct: (Scope, any, ...any) -> any,
	addPromise: <T>(Scope, T) -> T,
	discard: (Scope, any) -> boolean,
	bindToRenderStep: (Scope, string, number, (number) -> ()) -> (),
	attachToInstance: (Scope, Instance) -> any,
	wrapClean: (Scope) -> (() -> ()),
}

function Scythe.add(scope, value, method)
	if method then
		core.add(scope, function() value[method](value) end)
	else
		core.add(scope, value)
	end
	return value
end

function Scythe.destroy(scope)
	if core.isAlive(scope) then
		core.destroy(scope)
	end
end

function Scythe.extend(scope)
	return core.add(scope, core.scope())
end

function Scythe.connect(scope, signal, callback)
	return core.add(scope, signal:Connect(callback))
end

function Scythe.once(scope, signal, callback)
	return core.add(scope, signal:Once(callback))
end

function Scythe.clone(scope, instance)
	return core.add(scope, instance:Clone())
end

function Scythe.construct(scope, class, ...)
	return core.add(scope, if type(class) == "table" then class.new(...) else class(...))
end

function Scythe.addPromise(scope, promise)
	if promise:getStatus() == "Started" then
		local cancel = core.add(scope, function() promise:cancel() end)
		promise:finally(function()
			if core.isAlive(scope) then
				core.remove(scope, cancel)
			end
		end)
	end
	return promise
end

function Scythe.discard(scope, value)
	if not core.remove(scope, value) then
		return false
	end
	if type(value) == "number" then
		Scythe.destroy(value)
	else
		local disposal = core.scope()
		core.add(disposal, value)
		core.destroy(disposal)
	end
	return true
end

function Scythe.bindToRenderStep(scope, name, priority, callback)
	runServ:BindToRenderStep(name, priority, callback)
	core.add(scope, function() runServ:UnbindFromRenderStep(name) end)
end

function Scythe.attachToInstance(scope, instance)
	return Scythe.connect(scope, instance.Destroying, function()
		Scythe.destroy(scope)
	end)
end

function Scythe.wrapClean(scope)
	return function() core.clean(scope) end
end

return table.freeze(Scythe) :: Facade