--!strict

local bn = require(game:GetService("ReplicatedStorage").Modules.Imported.Backend.ByteNetMax)

return bn.defineNamespace("Pickup", function()
	return {
		structs = {},
		queries = {
			Collect = bn.defineQuery({request = bn.uint32, response = bn.string}),
		},
		packets = {
			Collected = bn.definePacket({
				value = bn.struct({id = bn.uint32, playerId = bn.float64, character = bn.inst, position = bn.vec3, amount = bn.uint32, at = bn.float64}),
				reliabilityType = "reliable",
			}),
		},
	}
end)