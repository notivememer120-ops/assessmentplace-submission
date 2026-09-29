--!strict
local bn = require(game:GetService("ReplicatedStorage").Modules.Imported.Backend.ByteNetMax)

return bn.defineNamespace("Movement", function()
	return {
		packets = {
			SprintIntent = bn.definePacket({
				value = bn.struct({
					running = bn.bool,
				}),

				reliabilityType = "reliable",
			}),
		},
	}
end)