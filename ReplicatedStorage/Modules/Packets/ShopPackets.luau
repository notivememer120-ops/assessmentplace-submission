--!strict
local bn = require(game:GetService("ReplicatedStorage").Modules.Imported.Backend.ByteNetMax)

return bn.defineNamespace("Shop", function()
	return {
		queries = {
			Buy = bn.defineQuery({
				request = bn.struct({id = bn.uint32, key = bn.string}),
				response = bn.string,
			}),
		},
	}
end)