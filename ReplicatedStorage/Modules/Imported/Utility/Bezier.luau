local function cubicBezier(t, p0, p1, p2, p3)
	return (1 - t)^3*p0 + 3*(1 - t)^2*t*p1 + 3*(1 - t)*t^2*p2 + t^3*p3
end

local function CreateLUT(numSegments, ...)
	local distSum = 0
	local sums = {}
	local step = 1/numSegments
	
	for i = 0, 1, step do
		local firstPoint = cubicBezier(i, ...)
		local secondPoint = cubicBezier(i+step, ...)
		local dist = (secondPoint - firstPoint).Magnitude
		table.insert(sums,distSum)
		distSum +=dist
	end
	return sums
end

local function remap(n,oldMin,oldMax,min,max)
	return (min +((max-min)*((n-oldMin)/(oldMax-oldMin))))
end


local Bezier = {}
Bezier.__index = Bezier

function Bezier.new(numSegments,p0,p1,p2,p3)
	local self = setmetatable({
		_points = {p0,p1,p2,p3};
		_distLut = CreateLUT(numSegments,p0,p1,p2,p3)
	},Bezier)
	
	return self
end

function Bezier:Calc(t)
	local LUT = self._distLut
	local arcLenghth = LUT[#LUT]
	local targetDist = arcLenghth * t
	
	for i, dist in ipairs(LUT) do
		local nextDist = LUT[i+1]
		if targetDist >= dist and targetDist < nextDist then
			local adjusted = remap(targetDist,dist,nextDist,i/#LUT,(i+1)/#LUT)
			return cubicBezier(adjusted,unpack(self._points))
		end
	end
	
end

return Bezier