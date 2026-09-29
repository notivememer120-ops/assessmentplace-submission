--!strict

local bn = require(game:GetService("ReplicatedStorage").Modules.Imported.Backend.ByteNetMax)

return bn.defineNamespace("Bag", function()
	return {
		packets = {},
		structs = {},
		queries = {
			Upgrade = bn.defineQuery({request = bn.nothing, response = bn.string}),
		},
	}
end)