--!strict
local players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local playerGroup = "Player"

local BanService: typeof(require(script.Parent.BanService))
local DataManager: typeof(require(script.Parent.DataManager))

local PlayerAddedInit = {}
PlayerAddedInit.__slittttName = "PlayerAddedInit"
PlayerAddedInit.Dependencies = {"BanService", "DataManager", "LeaderstatsService", "AdminService", "GamepassService", "SettingsService", "MovementService", "TutorialService", "DeathService", "BagService", "PickupService", "ShopService", "RespawnService"}

type Target = {
	__slittttName: string,
	[string]: unknown,
}

local joinTargets: {Target}
local removeTargets: {Target}

local function fanout(targets: {Target}, method: "OnPlayerJoined" | "OnPlayerRemoving", player: Player)
	for _, service in targets do
		local s, err = xpcall(service[method] :: (unknown, Player) -> unknown, debug.traceback :: (string) -> string, service, player)
		
		if not s then
			task.spawn(error, `{service.__slittttName}:{method} failed for {player.Name}:\n{err}`)
		end
	end
end

local function onCharacterAdded(char: Model)
	char.Parent = workspace.Players

	for _, part in char:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = playerGroup
		end
	end

	char.DescendantAdded:Connect(function(desc)
		if desc:IsA("BasePart") then
			desc.CollisionGroup = playerGroup
		end
	end)
end

local function onPlayerAdded(player: Player)
	if BanService:CheckAndKick(player) then
		return
	end

	-- errors when the player leaves b4 their profile loads - a normal exit, not a fault
	local s = pcall(function()
		DataManager:AwaitProfile(player)
	end)

	if not s or not player.Parent then
		return
	end

	DataManager:AddTimesJoined(player, 1):catch(function(err)
		task.spawn(error, `AddTimesJoined failed for {player.Name}: {tostring(err)}`)
	end)

	player.CharacterAdded:Connect(onCharacterAdded)
	
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end

	fanout(joinTargets, "OnPlayerJoined", player)
end

local function onPlayerRemoving(player: Player)
	fanout(removeTargets, "OnPlayerRemoving", player)
end

function PlayerAddedInit.Init(self: {Get: (unknown, string) -> unknown})
	PhysicsService:CollisionGroupSetCollidable(playerGroup, playerGroup, false)

	BanService = self:Get("BanService") :: typeof(require(script.Parent.BanService))
	DataManager = self:Get("DataManager") :: typeof(require(script.Parent.DataManager))

	joinTargets = ({
		self:Get("LeaderstatsService"),
		self:Get("AdminService"),
		self:Get("GamepassService"),
		self:Get("MovementService"),
		self:Get("TutorialService"),
		self:Get("DeathService"),
		self:Get("BagService"),
		self:Get("PickupService"),
		self:Get("ShopService"),
		self:Get("RespawnService"),
	} :: unknown) :: {Target}

	removeTargets = ({
		self:Get("GamepassService"),
		self:Get("SettingsService"),
		self:Get("MovementService"),
		self:Get("TutorialService"),
		self:Get("DeathService"),
		self:Get("BagService"),
		self:Get("PickupService"),
		self:Get("ShopService"),
		self:Get("RespawnService"),
	} :: unknown) :: {Target}

	players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)

	players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return PlayerAddedInit