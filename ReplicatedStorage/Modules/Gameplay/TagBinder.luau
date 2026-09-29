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
	local collection = collectionServ:CreateCollection(`.{tag}`, parent)
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

		collection:Destroy()

		Scythe.destroy(bindingScope)

		for instance in scopes do
			remove(instance)
		end
	end

	Scythe.connect(bindingScope, parent.Destroying, stop)

	collection.OnRemoved = remove

	collection.OnAdded = function(instance)
		if stopped or scopes[instance] then
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

	local count = 0

	collection:ForEach(function()
		count += 1
	end)

	--if count == 0 then

	--end

	return stop
end

return TagBinder