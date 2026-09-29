--!strict
local ts = game:GetService("TweenService")

local UIFade = {}

type Job = {o: Instance, props: {[string]: number}}

local function fadeProps(o: Instance, add: (Instance, string) -> ()): boolean
	if o:IsA("CanvasGroup") then
		add(o, "GroupTransparency")
		add(o, "BackgroundTransparency")
		return true
	end

	if o:IsA("GuiObject") then
		add(o, "BackgroundTransparency")
		
		if o:IsA("ImageLabel") or o:IsA("ImageButton") then
			add(o, "ImageTransparency")
		end

		if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
			add(o, "TextTransparency")
			add(o, "TextStrokeTransparency")
		end

		return false
	end

	if o:IsA("UIStroke") or o:IsA("UIShadow") then
		add(o, "Transparency")
		return true
	end

	return true
end

local function walkFades(parent: Instance, add: (Instance, string) -> ())
	for _, c in parent:GetChildren() do
		if fadeProps(c, add) == false then
			walkFades(c, add)
		end
	end
end

local function fadeJobs(root: Instance, targetOf: (number) -> number): {Job}
	local jobs: {Job} = {}
	local byObj: {[Instance]: {[string]: number}} = {}

	walkFades(root, function(o: Instance, prop: string)
		local r = UIFade.restOf(o, prop)

		if r < 1 then
			local e = byObj[o]

			if not e then
				e = {}
				byObj[o] = e
				jobs[#jobs + 1] = {o = o, props = e}
			end

			e[prop] = targetOf(r)
		end
	end)

	return jobs
end

function UIFade.restOf(o: Instance, prop: string): number
	local a = o:GetAttribute(`_fx_{prop}`)

	if a ~= nil then
		return a :: number
	end

	-- baseline lives ON the instance: a lua-side cache entry can get GC'd while
	-- the element sits faded out, and the re-capture would read 1 as "normal".
	-- attributes also die with the element, so rebuilt grids don't leak
	o:SetAttribute(`_fx_{prop}`, (o :: any)[prop])

	return (o :: any)[prop] :: number
end

function UIFade.fadeIn(root: Instance, info: TweenInfo)
	local jobs = fadeJobs(root, function(r)
		return r
	end)

	for _, j in jobs do
		for prop in j.props do
			(j.o :: any)[prop] = 1
		end
	end

	for _, j in jobs do
		ts:Create(j.o, info, j.props):Play()
	end
end

function UIFade.fadeOut(root: Instance, info: TweenInfo)
	local jobs = fadeJobs(root, function(_rest: number): number
		return 1
	end)

	for _, j in jobs do
		ts:Create(j.o, info, j.props):Play()
	end
end

return UIFade