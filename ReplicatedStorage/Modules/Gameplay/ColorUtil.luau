local ColorUtil = {}

function ColorUtil.luma(c)
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

function ColorUtil.bright(c, target)
	local h, s, v = c:ToHSV()
	local o = Color3.fromHSV(h, math.min(1, s * 1.15), math.max(v, 0.9))
	local l = ColorUtil.luma(o)
	
	if l < target then
		o = o:Lerp(Color3.new(1, 1, 1), (target - l) / (1 - l))
	end
	
	return o
end

return ColorUtil