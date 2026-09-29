--!strict
local bn = require(game:GetService("ReplicatedStorage").Modules.Imported.Backend.ByteNetMax)

return bn.defineNamespace("Notify", function()
	return {
		packets = {
			ServerNotice = bn.definePacket({
				value = bn.struct({
					kind = bn.uint8,
					title = bn.string,
					text = bn.string,
					count = bn.uint16,
					urgent = bn.bool,
				}),

				reliabilityType = "reliable",
			}),
		},
	}
end)