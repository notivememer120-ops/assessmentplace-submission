local textService = game:GetService("TextService")
local rep = game:GetService("ReplicatedStorage")

local UILib = require(rep.Modules.Gameplay.UILib)

local TextTruncate = {}

function TextTruncate.fit(d)
	local full = d:GetAttribute("FullDesc")

	if not full then
		return
	end

	local scale = UILib.renderScale(d)
	local w = d.AbsoluteSize.X / scale - 2
	local maxH = d.AbsoluteSize.Y / scale + 1
	
	if w < 20 then
		return
	end

	local params = Instance.new("GetTextBoundsParams")
	params.Font = d.FontFace
	params.Size = d.TextSize

	local function height(t)
		params.Text = t
		params.Width = w
		
		local s, bounds = pcall(textService.GetTextBoundsAsync, textService, params)
		return s and bounds.Y or 0
	end

	if height(full) <= maxH then
		d.Text = full
		return
	end

	local words = {}
	
	for word in full:gmatch("%S+") do
		words[#words + 1] = word
	end

	local lo = 1
	local hi = #words - 1
	
	while lo < hi do
		local mid = math.ceil((lo + hi) / 2)
		
		if height(`{table.concat(words, " ", 1, mid)}…`) <= maxH then
			lo = mid
		else
			hi = mid - 1
		end
	end

	d.Text = `{table.concat(words, " ", 1, lo)}…`
end

function TextTruncate.arm(d)
	local pending = false
	
	local function kick()
		if pending then
			return
		end

		pending = true
		
		task.delay(0, function()
			pending = false

			task.spawn(TextTruncate.fit, d)
		end)
	end

	d:GetPropertyChangedSignal("AbsoluteSize"):Connect(kick)

	kick()
end

return TextTruncate