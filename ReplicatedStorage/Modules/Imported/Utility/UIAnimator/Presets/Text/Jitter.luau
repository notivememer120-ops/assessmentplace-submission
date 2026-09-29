local Scythe = require(game:GetService("ReplicatedStorage").Modules.Imported.Utility.Scythe)

local CharBuilder = require(script.Parent.CharBuilder)

-- interval — time between each character appearing
-- speed —  how fast each character shifts to a new jitter position
-- intensity — how many pixels each character shifts in any direction
return function(container, label, text, lineHeight, boundX, scope, options)
	local speed = options.speed or 0.05
	local intensity = options.intensity or 2
	local interval = options.interval or 0.05
	local charList = CharBuilder.buildLines(text, label, boundX)

	for _, data in ipairs(charList) do
		if not Scythe.isAlive(scope) then return end
		if data.char:match("%s") then continue end

		local charLabel = CharBuilder.createCharLabel(data, label, container)
		charLabel:SetAttribute("CharLabel", true)
		
		Scythe.add(scope, charLabel)

		local basePos = charLabel.Position
		Scythe.add(scope, task.spawn(function()
			while charLabel and charLabel.Parent do
				local jitterX = math.random(-intensity, intensity)
				local jitterY = math.random(-intensity, intensity)
				charLabel.Position = UDim2.new(
					basePos.X.Scale, basePos.X.Offset + jitterX,
					basePos.Y.Scale, basePos.Y.Offset + jitterY
				)
				task.wait(speed)
			end
		end))

		task.wait(interval)
	end
end