local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Modules.Imported.Utility.Signal)

local LoadingScreenEvents = {}
LoadingScreenEvents.AboutToHide = Signal()
LoadingScreenEvents.HasHidden = false
LoadingScreenEvents.ClientReady = false

return LoadingScreenEvents