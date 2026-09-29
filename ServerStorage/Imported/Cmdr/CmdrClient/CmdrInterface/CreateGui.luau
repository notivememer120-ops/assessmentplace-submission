const Players = game:GetService("Players")
const rep = game:GetService("ReplicatedStorage")
const WaitFor = require(rep.Modules.Gameplay.WaitFor)

return function(): ScreenGui
	return WaitFor:get(Players.LocalPlayer.PlayerGui, "Cmdr")
end