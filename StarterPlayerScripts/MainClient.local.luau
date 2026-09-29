-- tung tung tung tung sahur
-- knit is deprecated im NOT using it

local rep = game:GetService("ReplicatedStorage")
local Logger = require(rep:WaitForChild("Modules"):WaitForChild("Imported"):WaitForChild("Utility"):WaitForChild("Logger"))
local finishData = Logger.begin("startup", "DataService:init")
local DataService = require(rep:WaitForChild('Modules', 90):WaitForChild('Imported'):WaitForChild('Backend', 90):WaitForChild('DataService')).client
DataService:init()
finishData()

local finishLoad = Logger.begin("startup", "game:IsLoaded")
repeat task.wait() until game:IsLoaded()
finishLoad()

local guiService = game:GetService("GuiService")
guiService.GuiNavigationEnabled = false
guiService.AutoSelectGuiEnabled = false

local Framework = require(game:GetService("ReplicatedStorage"):WaitForChild('Modules'):WaitForChild('Gameplay').Framework)
local LoadingScreenEvents = require(game:GetService("ReplicatedStorage").Modules.Gameplay.LoadingScreenEvents)
local loadingScreen = game:GetService("ReplicatedFirst"):FindFirstChild("LoadingScreen")

if not loadingScreen or not loadingScreen.Enabled then
	LoadingScreenEvents.HasHidden = true
end

Framework:AddModules(script.Parent:WaitForChild("ClientModules"))
--Framework._debug = true

Framework:Run():andThen(function()
	LoadingScreenEvents.ClientReady = true
	print("C✅")
	if not game:GetService('RunService'):IsStudio() then
		print('codebase written by Dave')
		print('with <3')
		print('---')
		print('this is a really crucial step! do not remove these prints, even if you are not a believer')
		print("Rahman ve Rahim olan Allah'ın adıyla, bu kodu şeytandan koru")
	end
	
	task.spawn(function()
		for _, v in game:GetService("StarterGui"):GetChildren() do
			v:Destroy()
		end

		--game:GetService("StarterGui").ChildAdded:Connect(function(v)
		--	v:Destroy()
		--end)
	end)
	
end):catch(function(err)
	-- a partial boot still beats holding the curtain the full cap for every player
	LoadingScreenEvents.ClientReady = true
	task.spawn(error, err)
end)