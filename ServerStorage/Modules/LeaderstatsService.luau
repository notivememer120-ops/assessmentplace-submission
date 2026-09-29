--!strict
local LeaderstatsService = {}
LeaderstatsService.__slittttName = "LeaderstatsService"
LeaderstatsService.Dependencies = {"DataManager"}

local DataManager: typeof(require(script.Parent.DataManager))

local keyToStat: {[string]: string} = {
	cash = "Cash",
}

function LeaderstatsService:OnPlayerJoined(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = DataManager:GetStat(player, "cash") or 0
	cash.Parent = folder

	folder.Parent = player
end

function LeaderstatsService.Init(self: {Get: (unknown, string) -> unknown})
	DataManager = self:Get("DataManager") :: typeof(require(script.Parent.DataManager))

	DataManager.StatChanged:Connect(function(player, key, value)
		local statName = keyToStat[key]
		
		if not statName then
			return
		end

		local folder = player:FindFirstChild("leaderstats")
		local stat = (folder and folder:FindFirstChild(statName)) :: IntValue?
		
		if stat then
			stat.Value = value
		end
	end)
end

return LeaderstatsService