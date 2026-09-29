local Ease = {}

function Ease.smoothstep(t)
	if t <= 0 then
		return 0
	elseif t >= 1 then
		return 1
	end

	return t * t * (3 - 2 * t)
end

function Ease.smoothstepSlope(t)
	if t <= 0 or t >= 1 then
		return 0
	end

	return 6 * t * (1 - t)
end

return Ease