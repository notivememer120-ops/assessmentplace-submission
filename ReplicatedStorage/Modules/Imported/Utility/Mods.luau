local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local CollectionSerivce = game:GetService("CollectionService")

local Assets = ReplicatedStorage.Assets
local Sounds = Assets.Sounds

local Tween = require(ReplicatedStorage.Modules.Imported.Backend.Tween)
local NewRandom = Random.new()

local Threads = {}
local Mods = {}

function Mods.Lerp(start, finish, alpha)
	return start + (finish - start) * alpha
end

--pass a table of tweens to make them all play in order or pass a number to make it wait that amount in seconds, wont wait anymore this so pointless w wait, returns thread and waittime: number
function Mods.ScheduleTweens(Tweens: {})
	local WaitTime = 0
	for _, Value: any in pairs(Tweens) do
		if type(Value) == "number" then
			WaitTime += Value
		end
	end
	
	return task.spawn(function()
		for _, Tween: Tween in pairs(Tweens) do
			if type(Tween) ~= "number" then
				Tween:Play()
			else
				task.wait(Tween)
			end
		end
	end), WaitTime
end
--silly, optionargs are, TweenInfo, ToPosition, Color, Size and ParentTo
function Mods.UniqueMessage(Text: string, Options: {})
	local Label = Assets.Ui.Other.DebugText:Clone()
	Label.TextColor3 = Options.Color or Color3.new(1, 1, 1)
	Label.Text = Text
	Label.Position = Options.FromPosition or UDim2.fromScale(0.5, 0.5)
	Label.Size = Options.Size or Label.Size
	Label.Parent = Options.ParentTo
	
	local TweenInf: TweenInfo = Options.TweenInfo or TweenInfo.new(0.5)
	TweenService:Create(Label, TweenInf, {Position = Options.ToPosition or UDim2.fromScale(0.5, 0), TextTransparency = 1}):Play()
	Debris:AddItem(Label, TweenInf.Time)
end

function Mods.GetTaggedOfAnchestor(Anchestor: Instance, Tag: string)
	for _, Tagged: Instance in pairs(CollectionSerivce:GetTagged(Tag)) do
		if Tagged:IsDescendantOf(Anchestor) then
			return Tagged
		end
	end
end

--plays a single sound
function Mods.PlaySingleSound(SoundPath: Sound, RandomizePitch: boolean, CustomParent: Instance, ReturnsInstance: boolean)
	local Sound = SoundPath:Clone()
	Sound.Parent = CustomParent or workspace

	if RandomizePitch then
		Sound.PlaybackSpeed = NewRandom:NextNumber(0.8, 1.2)
	end

	Sound:Play()
	if not Sound.IsLoaded then
		Sound.Loaded:Wait()
	end
	Debris:AddItem(Sound, Sound.TimeLength * Sound.PlaybackSpeed)
	
	if ReturnsInstance then
		return Sound
	end
end

function Mods.comma_value(amount)
	local formatted = tostring(math.floor(amount)) -- <edit>
	local k = 0 -- </edit>
	
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			break
		end
	end
	
	return formatted
end

return Mods