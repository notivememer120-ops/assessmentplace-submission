local Scythe = require(game:GetService("ReplicatedStorage").Modules.Imported.Utility.Scythe)

-- interval — time between each character appearing
-- speed — N/A
-- intensity — N/A
return function(container, label: TextLabel | TextButton | TextBox, text: string, lineHeight, boundX, scope: Scythe.Scope, options: {interval: number?})
	local interval = options.interval or 0.05

	label.Text = text
	label.MaxVisibleGraphemes = 0
	label.Visible = true

	local visible = 0
	for _ in utf8.graphemes(label.ContentText) do
		if not Scythe.isAlive(scope) then return end
		visible += 1
		label.MaxVisibleGraphemes = visible
		task.wait(interval)
	end
end