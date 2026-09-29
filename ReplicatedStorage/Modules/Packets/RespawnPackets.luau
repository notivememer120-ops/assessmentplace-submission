--!strict
local bn = require(game:GetService("ReplicatedStorage").Modules.Imported.Backend.ByteNetMax)

return bn.defineNamespace("Respawn", function()
	local function emptyPacket()
		return bn.definePacket({
			value = bn.nothing,
			reliabilityType = "reliable",
		})
	end

	return {
		packets = {
			Reset = emptyPacket(),
			Request = emptyPacket(),
		},
	}
end)