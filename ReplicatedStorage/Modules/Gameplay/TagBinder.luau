--!strict
local collectionServ = game:GetService("CollectionService")
local rep = game:GetService("ReplicatedStorage")

local Scythe = require(rep.Modules.Imported.Utility.Scythe)

local TagBinder = {}

function TagBinder.bind(tag: string, callback: (any, Scythe.Scope) -> ...any, root: Instance?): () -> ()
	if not root then
		root = workspace
	end

	local parent = root :: Instance
	local bindingScope = Scythe.scope()
	local scopes: {[Instance]: Scythe.Scope} = {}
	local stopped = false

	local function remove(instance)
		local scope = scopes[instance]

		if not scope then
			return
		end

		scopes[instance] = nil

		Scythe.destroy(scope)
	end

	local function stop()
		if stopped then
			return
		end

		stopped = true

		Scythe.destroy(bindingScope)

		for instance in scopes do
			remove(instance)
		end
	end

	local function add(instance: Instance)
		if stopped or scopes[instance] or not instance:IsDescendantOf(parent) or not collectionServ:HasTag(instance, tag) then
			return
		end

		local scope = Scythe.scope()

		scopes[instance] = scope

		local s, err = xpcall(callback, function(err)
			return debug.traceback(tostring(err), 2)
		end, instance, scope)

		if not s then
			stop()
			error(err, 0)
		end
	end

	Scythe.connect(bindingScope, parent.Destroying, stop)
	Scythe.connect(bindingScope, parent.DescendantAdded, add)
	Scythe.connect(bindingScope, parent.DescendantRemoving, remove)
	Scythe.connect(bindingScope, collectionServ:GetInstanceAddedSignal(tag), add)
	Scythe.connect(bindingScope, collectionServ:GetInstanceRemovedSignal(tag), remove)

	for _, instance in collectionServ:GetTagged(tag) do
		add(instance)
	end

	return stop
end

return TagBinder
