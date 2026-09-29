--!strict
local bn = require(game:GetService("ReplicatedStorage").Modules.Imported.Backend.ByteNetMax)

return bn.defineNamespace("Admin", function()
	return {
		packets = {
			AdminReq = bn.definePacket({
				value = bn.struct({
					action = bn.string,
					payload = bn.string,
				}),
				
				reliabilityType = "reliable",
			}),

			AdminSync = bn.definePacket({
				value = bn.struct({
					kind = bn.string,
					payload = bn.string,
				}),
				
				reliabilityType = "reliable",
			}),
		},
	}
end)