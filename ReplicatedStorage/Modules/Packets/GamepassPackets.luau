--!strict
local bn = require(game:GetService("ReplicatedStorage").Modules.Imported.Backend.ByteNetMax)

return bn.defineNamespace("Gamepass", function()
	return {
		packets = {
			OwnershipSync = bn.definePacket({
				value = bn.struct({
					passes = bn.array(bn.string),
				}),
				
				reliabilityType = "reliable",
			}),

			-- C2S: pull current ownership on boot (mirrors AdminReq "hello")
			RequestOwnership = bn.definePacket({
				value = bn.nothing,
				reliabilityType = "reliable",
			}),
		},
	}
end)