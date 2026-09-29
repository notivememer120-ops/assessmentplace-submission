--!strict
local bn = require(game:GetService("ReplicatedStorage").Modules.Imported.Backend.ByteNetMax)

return bn.defineNamespace("Report", function()
	return {
		packets = {
			Submit = bn.definePacket({
				value = bn.struct({
					requestId = bn.string,
					encoded = bn.string,
					device = bn.string,
				}),
				reliabilityType = "reliable",
			}),

			Result = bn.definePacket({
				value = bn.struct({
					requestId = bn.string,
					ok = bn.bool,
					reason = bn.string,
					remaining = bn.uint16,
					cooldown = bn.uint16,
				}),
				reliabilityType = "reliable",
			}),
		},
	}
end)