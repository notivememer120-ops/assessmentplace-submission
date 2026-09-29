--!strict

local rep = game:GetService("ReplicatedStorage")
local storage = game:GetService("ServerStorage")
local collectionServ = game:GetService("CollectionService")

local config = require(rep.Modules.Configs.PickupConfig)
local assessment = require(rep.Modules.Configs.AssessmentConfig)
local network = require(rep.Modules.Packets.PickupPackets)
local Types = require(rep.Modules.Gameplay.AssessmentTypes)
local TagBinder = require(rep.Modules.Gameplay.TagBinder)
local RateGate = require(rep.Modules.Gameplay.RateGate)
local Timer = require(rep.Modules.Imported.Backend.Timer)
local Scythe = require(rep.Modules.Imported.Utility.Scythe)
local BagService = require(script.Parent.BagService)
local Analytics = require(script.Parent.AnalyticsService)

type Slot = {
	id: number,
	zone: number,
	marker: BasePart,
	item: Model?,
	claimed: boolean,
	removeAt: number?,
}

local slots: {[number]: Slot} = {}
local admitted: {[Player]: boolean} = {}
local gate = RateGate.new(assessment.requestInterval)
local random = Random.new()
local sight = RaycastParams.new()
local scope: number
local folder: Folder
local template: Model
local barrier: BasePart
local zone1Collected = 0
local totalCollected = 0

local PickupService = {}
PickupService.__slittttName = "PickupService"
PickupService.Dependencies = {"BagService", "AnalyticsService"}

function PickupService:Collect(player: Player, id: number): Types.PickupResult
	if not admitted[player] then return "inactive" end

	if gate:tooFast(player) then return "busy" end

	local slot = slots[id]

	if not slot then return "missing" end

	if slot.claimed then return "claimed" end

	if slot.zone == 2 and zone1Collected < assessment.zone1Count then return "locked" end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")

	if not hum or hum.Health <= 0 or not hum.RootPart then return "inactive" end

	local delta = slot.marker.Position - hum.RootPart.Position

	if delta.Magnitude > config.range then return "range" end

	if workspace:Raycast(hum.RootPart.Position, delta, sight) then return "blocked" end

	local result: Types.PickupResult = BagService:CanCollect(player)

	if result ~= "ok" then return result end

	slot.claimed = true

	BagService:Add(player)

	totalCollected += 1

	if slot.zone == 1 then
		zone1Collected += 1

		workspace:SetAttribute("Zone1Collected", zone1Collected)

		if zone1Collected == assessment.zone1Count then
			barrier.CanCollide = false
			barrier.Transparency = 1

			workspace:SetAttribute("Zone2Open", true)
		end
	end

	workspace:SetAttribute("TotalCollected", totalCollected)

	local item = slot.item :: Model
	item:SetAttribute("Claimed", true)

	network.packets.Collected.sendToAll({id = id, playerId = player.UserId, character = char :: Model, position = slot.marker.Position, amount = 1, at = workspace:GetServerTimeNow()})

	slot.removeAt = os.clock() + config.replicationSeconds

	Analytics:Track("collect", player, {id = id, zone = slot.zone, total = totalCollected})
	return "ok"
end

function PickupService:Init()
	scope = Scythe.scope()
	template = storage.PickupTemplates.Coin
	barrier = workspace.Map.Assessment.Gate
	barrier.CanCollide = true
	barrier.Transparency = 0.25
	zone1Collected = 0
	totalCollected = 0

	workspace:SetAttribute("Zone1Collected", 0)
	workspace:SetAttribute("TotalCollected", 0)
	workspace:SetAttribute("Zone2Open", false)

	folder = Scythe.add(scope, Instance.new("Folder"))
	folder.Name = "Pickups"
	folder.Parent = workspace
	sight.FilterType = Enum.RaycastFilterType.Exclude
	sight.FilterDescendantsInstances = {workspace.Players, folder}
	sight.RespectCanCollide = true

	Scythe.add(scope, TagBinder.bind(config.spawnTag, function(marker: BasePart, owner: number)
		local id = marker:GetAttribute("CollectibleId") :: number
		local item = Scythe.add(owner, template:Clone())
		local slot: Slot = {id = id, zone = marker:GetAttribute("Zone") :: number, marker = marker, item = item, claimed = false}

		slots[id] = slot

		item:PivotTo(marker.CFrame)
		item:SetAttribute("PickupId", id)
		item:SetAttribute("Zone", slot.zone)
		item:SetAttribute("PickupOrigin", marker.CFrame)
		item:SetAttribute("PickupPhase", random:NextNumber(0, math.pi * 2))
		item:SetAttribute("Claimed", false)
		item:AddTag(config.tag)
		item.Parent = folder

		Scythe.add(owner, function() slots[id] = nil end)
	end, workspace))

	if #collectionServ:GetTagged(config.spawnTag) == 0 then warn(`No {config.spawnTag} pickup markers in Workspace`) end

	Scythe.add(scope, network.queries.Collect.listen(function(id: number, player): string return self:Collect(player :: Player, id) end))

	local timer = Scythe.add(scope, Timer.new(config.interval))

	Scythe.connect(scope, timer.Tick, function()
		local now = os.clock()

		for _, slot in slots do
			if slot.removeAt and now >= slot.removeAt then
				(slot.item :: Model):Destroy()

				slot.item = nil
				slot.removeAt = nil
			end
		end
	end)

	timer:Start()
end

function PickupService:OnPlayerJoined(player: Player)
	admitted[player] = true
end

function PickupService:OnPlayerRemoving(player: Player)
	admitted[player] = nil

	gate:forget(player)
end

function PickupService:Destroy()
	Scythe.destroy(scope)

	for player in admitted do self:OnPlayerRemoving(player) end

	table.clear(slots)
end

return PickupService