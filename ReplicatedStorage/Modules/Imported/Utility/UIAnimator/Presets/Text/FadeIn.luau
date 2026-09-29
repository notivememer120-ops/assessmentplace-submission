local Scythe = require(game:GetService("ReplicatedStorage").Modules.Imported.Utility.Scythe)

local CharBuilder = require(script.Parent.CharBuilder)
local TS = game:GetService("TweenService")

-- interval : time between each character starting its fade
-- speed    : how long each character takes to fade in
-- intensity: starting transparency (1 = fully invisible, 0.5 = half visible), default 1
return function(container, label, text, lineHeight, boundX, scope, options)
	local interval = options.interval or 0.05
	local speed = options.speed or 0.3
	local intensity = options.intensity or 1
	local charList = CharBuilder.buildLines(text, label, boundX)

	for _, data in ipairs(charList) do
		if not Scythe.isAlive(scope) then return end
		if data.char:match("%s") then continue end

		local charLabel = CharBuilder.createCharLabel(data, label, container)
		charLabel:SetAttribute("CharLabel", true)
		charLabel.TextTransparency = intensity
		Scythe.add(scope, charLabel)

		local tweenInfo = TweenInfo.new(speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TS:Create(charLabel, tweenInfo, {TextTransparency = 0}):Play()

		task.wait(interval)
	end
end