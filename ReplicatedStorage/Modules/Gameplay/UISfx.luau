local SoundService = game:GetService("SoundService")
local rep = game:GetService("ReplicatedStorage")

local WaitFor = require(rep.Modules.Gameplay.WaitFor)

local folder = WaitFor:get(SoundService, "SFX")
local sounds = {}

local UISfx = {}
local lastAt = {}
local minGap = 0.045
local live = setmetatable({}, {__mode = "kv"})

local duckUntil = 0

local function resolve(name)
	if not sounds[name] then
		sounds[name] = folder:FindFirstChild(name)
	end

	if not sounds[name] then
		warn(`UISfx: add a sound named {name} to SoundService.SFX`)
	end

	return sounds[name]
end

function UISfx.play(name)
	local sound = resolve(name)

	if not sound then
		return
	end

	local now = os.clock()

	if lastAt[name] and now - lastAt[name] < minGap then
		return
	end

	if name ~= "Success2" and now < duckUntil then
		return
	end

	lastAt[name] = now

	if name == "Success2" then
		local dur = sound.TimeLength

		duckUntil = now + (dur > 0 and dur or 2.5)
	end

	local clone = sound:Clone()

	live[clone] = true
	clone.Parent = folder
	clone:Destroy() -- clones have PlayOnRemove==true so yeah dw
end

function UISfx.attach(name, parent)
	local sound = resolve(name)

	if not sound then
		return
	end

	local clone = sound:Clone()
	clone.PlayOnRemove = false
	clone.Parent = parent
	clone:Play()

	return clone
end

return UISfx