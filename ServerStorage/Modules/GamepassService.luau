--!strict
local rep = game:GetService("ReplicatedStorage")
local runServ = game:GetService("RunService")

local Gamepasses = require(rep.Modules.Configs.Monetization.Gamepasses)
local GamepassPackets = require(rep.Modules.Packets.GamepassPackets)
local Monetization = require(rep.Modules.Gameplay.Monetization)

local GamepassService = {}
local DataManager: typeof(require(script.Parent.DataManager))

GamepassService.__slittttName = "GamepassService"
GamepassService.Dependencies = {"DataManager"}

local ownership:{[Player]:{[string]:boolean}} = {}

local function gamepassKeyForId(id:number): string?
	for key, cfg in Gamepasses do
		if type(cfg) ~= "table" then
			continue
		end

		if cfg.GamepassId == id then
			return key
		end
	end

	return nil
end

local function pushOwnership(player:Player)
	local cache = ownership[player]
	
	if not cache then
		return
	end

	local keys = {}
	
	for key in cache do
		table.insert(keys, key)
	end

	GamepassPackets.packets.OwnershipSync.sendTo({passes = keys}, player)
end

local function syncFromProfile(player:Player)
	local studio = runServ:IsStudio()


	for key, cfg in Gamepasses do
		if type(cfg) ~= "table" or not cfg.GamepassId then
			continue
		end

		-- leave-mid-sync boundary: the sync getter throws once a leaver's data is
		-- released, and this loop straddles marketplace yields
		local s, has = pcall(DataManager.HasOwnedPass, DataManager, player, key)

		if not s or not ownership[player] then
			return
		end

		if has then
			ownership[player][key] = true
			continue
		end

		if studio then
			continue
		end

		local fetched, owns = Monetization.userOwnsGamepass(player.UserId, cfg.GamepassId)

		if not ownership[player] then
			return
		end

		if not fetched then
			warn(`ownership fetch wrong for {player.Name} pass={key}: {tostring(owns)}`)
			continue
		end

		if owns then
			ownership[player][key] = true
			
			DataManager:AddOwnedPass(player, key):catch(function(err)
				task.spawn(error, `AddOwnedPass write wrong for {player.Name}/{key}: {tostring(err)}`)
			end)
		end
	end

	pushOwnership(player)
end

function GamepassService:OnPlayerJoined(player:Player)
	if ownership[player] then
		return
	end

	ownership[player] = {}

	task.spawn(syncFromProfile, player)
end

function GamepassService:OnPlayerRemoving(player:Player)
	ownership[player] = nil
end

function GamepassService:Owns(player:Player, key:string): boolean
	local cache = ownership[player]

	return cache ~= nil and cache[key] == true
end

function GamepassService:GrantPass(player:Player, key:string)
	local cache = ownership[player]
	
	if not cache then
		return
	end

	cache[key] = true

	DataManager:AddOwnedPass(player, key):catch(function(err)
		task.spawn(error, `AddOwnedPass write wrong for {player.Name}/{key}: {tostring(err)}`)
	end)

	pushOwnership(player)
end

function GamepassService:RevokePass(player:Player, key:string)
	local cache = ownership[player]
	
	if not cache then
		return
	end

	cache[key] = nil

	DataManager:RemoveOwnedPass(player, key):catch(function(err)
		task.spawn(error, `RemoveOwnedPass write wrong for {player.Name}/{key}: {tostring(err)}`)
	end)

	pushOwnership(player)
end

function GamepassService.Init(self: typeof(GamepassService) & {Get: (unknown, string) -> unknown})
	DataManager = self:Get("DataManager") :: typeof(require(script.Parent.DataManager))

	GamepassPackets.packets.RequestOwnership.listen(function(_, player)
		pushOwnership(player :: Player)
	end)

	Monetization.GamePassPurchaseFinished:Connect(function(sender, gamepassId, wasPurchased)
		local player = sender :: Player
		local key = gamepassKeyForId(gamepassId)

		if not key then
			return
		end

		if not wasPurchased then
			-- prompting a pass bought on the website mid-session closes as not-purchased;
			-- one re-check picks the ownership up w/out forcing a rejoin
			task.spawn(function()
				local s, owns = Monetization.userOwnsGamepass(player.UserId, gamepassId)

				if s and owns and ownership[player] and not ownership[player][key] then
					self:GrantPass(player, key)
				end
			end)

			return
		end

		if not ownership[player] then
			return
		end

		ownership[player][key] = true
		
		DataManager:AddOwnedPass(player, key):catch(function(err)
			task.spawn(error, `AddOwnedPass write wrong for {player.Name}/{key}: {tostring(err)}`)
		end)

		pushOwnership(player)
	end)
end

return GamepassService