local DeathService = require(game:GetService("ServerStorage").Modules.DeathService)

return function(_, players: { Player }): string
	for _, player in ipairs(players) do
		const character = player.Character
		const humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
		if not humanoid then
			continue
		end

		DeathService:Kill(humanoid, "admin")
	end

	return `Killed {#players} players.`
end