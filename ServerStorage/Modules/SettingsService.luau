--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsPackets = require(ReplicatedStorage.Modules.Packets.SettingsPackets)
local RateGate = require(ReplicatedStorage.Modules.Gameplay.RateGate)

local DataManager: typeof(require(script.Parent.DataManager))

local SettingsService = {}
SettingsService.__slittttName = "SettingsService"
SettingsService.Dependencies = {"DataManager"}

local saveGate = RateGate.new(0.2)

local function handleSaveRequest(data, player: Player)
	if type(data.muteMusic) ~= "boolean" or type(data.muteSfx) ~= "boolean" or type(data.hideChat) ~= "boolean"
		or type(data.showFps) ~= "boolean" or type(data.showServer) ~= "boolean"
		or type(data.cameraMovement) ~= "boolean" or type(data.sprintToggle) ~= "boolean" then
		warn(`{player.Name} sent invalid settings payload`)
		
		return
	end

	if saveGate:tooFast(player) then return end

	DataManager:SetSettings(player, {
		muteMusic = data.muteMusic,
		muteSfx = data.muteSfx,
		hideChat = data.hideChat,
		showFps = data.showFps,
		showServer = data.showServer,
		cameraMovement = data.cameraMovement,
		sprintToggle = data.sprintToggle,
	}):catch(function(err)
		task.spawn(error, `save settings fail for {player.Name} cuz {tostring(err)}`)
	end)
end

function SettingsService:OnPlayerRemoving(player: Player)
	saveGate:forget(player)
end

function SettingsService.Init(self: {Get: (unknown, string) -> unknown})
	DataManager = self:Get("DataManager") :: typeof(require(script.Parent.DataManager))

	SettingsPackets.packets.SaveSettingsReq.listen(function(data, player)
		handleSaveRequest(data, player :: Player)
	end)
end

return SettingsService