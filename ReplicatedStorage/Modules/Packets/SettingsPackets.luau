--!strict
local bn = require(game:GetService("ReplicatedStorage").Modules.Imported.Backend.ByteNetMax)

return bn.defineNamespace("Settings", function()
	return {
		packets = {
			SaveSettingsReq = bn.definePacket({
				value = bn.struct({
					muteMusic = bn.bool,
					muteSfx = bn.bool,
					hideChat = bn.bool,
					showFps = bn.bool,
					showServer = bn.bool,
					cameraMovement = bn.bool,
					sprintToggle = bn.bool,
				}),
				
				reliabilityType = "reliable",
			}),
		},
	}
end)