local SoundService = game:GetService("SoundService")
local rep = game:GetService("ReplicatedStorage")

local WaitFor = require(rep.Modules.Gameplay.WaitFor)

local MusicController = {}
MusicController.__slittttName = "MusicController"

function MusicController:Start()
	task.spawn(function()
		local track = WaitFor:chain(SoundService, {"Music", "Background"})
		track.Looped = true
		track:Play()
	end)
end

return MusicController