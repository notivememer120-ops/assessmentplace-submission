--!strict
local rep = game:GetService("ReplicatedStorage")

local Scythe = require(rep.Modules.Imported.Utility.Scythe)

local TutorialService = {}
TutorialService.__slittttName = "TutorialService"
TutorialService.Dependencies = {"DataManager"}

type Service = typeof(TutorialService) & {
	Get: (unknown, string) -> unknown,
	_scopes: {[Player]: number},
	_data: typeof(require(script.Parent.DataManager)),
}

function TutorialService.Init(self: Service)
	self._scopes = {} :: {[Player]: number}
	self._data = self:Get("DataManager") :: typeof(require(script.Parent.DataManager))
end

function TutorialService.OnPlayerJoined(self: Service, player: Player)
	local scope = Scythe.scope()

	self._scopes[player] = scope

	local complete = self._data:GetSprintTutorialCompleted(player)

	player:SetAttribute("SprintTutorialCompleted", complete)
	player:SetAttribute("TutorialReady", true)

	if complete then
		return
	end

	local function update()
		if complete or player:GetAttribute("sprinting") ~= true then
			return
		end

		self._data:SetSprintTutorialCompleted(player)

		complete = true

		player:SetAttribute("SprintTutorialCompleted", true)

		Scythe.clean(scope)
	end

	Scythe.connect(scope, player:GetAttributeChangedSignal("sprinting"), update)
	update()
end

function TutorialService.OnPlayerRemoving(self: Service, player: Player)
	local scope = self._scopes[player]

	if scope then
		Scythe.destroy(scope)

		self._scopes[player] = nil
	end
end

function TutorialService.Destroy(self: Service)
	for _, v in self._scopes do
		Scythe.destroy(v)
	end

	table.clear(self._scopes)
end

return TutorialService