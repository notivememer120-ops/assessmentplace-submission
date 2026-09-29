local player = game.Players.LocalPlayer
local PlayerModule = require(player.PlayerScripts:WaitForChild("PlayerModule", 90))
local controlModule = PlayerModule:GetControls()
local cameraModule = PlayerModule:GetCameras()

local API = {}

local controlsState = true

function API.ControlsDisable()
	controlModule:Disable()
	controlsState = false
end

function API.ControlsEnable()
	controlModule:Enable()
	controlsState = true
end

function API.GetControlsState()
	return controlsState
end

function API.ChangeCamera(enum: Enum.DevCameraOcclusionMode)
	cameraModule:ActivateOcclusionModule(enum)
end

return API