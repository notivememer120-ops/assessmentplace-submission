local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Framework = require(ReplicatedStorage.Modules.Gameplay.Framework)
local WaitFor = require(ReplicatedStorage.Modules.Gameplay.WaitFor)

require(ReplicatedStorage.Modules.Imported.Backend.Tween)

Framework:AddModules(WaitFor:get(ServerStorage, "Modules"))
--Framework._debug = true
Framework:Run():andThen(function()
	print("S✅")
end):catch(function(err)
	task.spawn(error, err)
end)