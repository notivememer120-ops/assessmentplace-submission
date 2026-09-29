--!strict
local rep = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local storage = game:GetService("ServerStorage")

local Scythe = require(rep.Modules.Imported.Utility.Scythe)

type Registry = {
	RegisterHook: (Registry, string, ({Executor: Player?}) -> string?, number?) -> (),
	RegisterDefaultCommands: (Registry, ({Name: string, Group: string}) -> boolean) -> (),
}

local CmdrService = {}
CmdrService.__slittttName = "CmdrService"
CmdrService.Dependencies = {"AdminService"}

function CmdrService.Init(self: {Get: (unknown, string) -> unknown, Cmdr: {Registry: Registry}, _scope: number})
	local admin = self:Get("AdminService") :: typeof(require(script.Parent.AdminService))
	local cmdr = require(storage.Imported.Cmdr) :: {Registry: Registry}

	self.Cmdr = cmdr
	self._scope = Scythe.scope()

	cmdr.Registry:RegisterHook("BeforeRun", function(context)
		if not context.Executor or not admin:IsAdmin(context.Executor) then
			return "You do not have permission to use developer commands"
		end

		return nil
	end)

	cmdr.Registry:RegisterDefaultCommands(function(command)
		return command.Name == "kill" or command.Group == "Help" or command.Group == "DefaultDebug" or command.Group == "DefaultUtil"
	end)

	local function joined(player: Player)
		player:SetAttribute("CmdrAllowed", admin:IsAdmin(player))
	end

	Scythe.connect(self._scope, players.PlayerAdded, joined)

	for _, v in players:GetPlayers() do
		joined(v)
	end
end

function CmdrService:Destroy()
	Scythe.destroy(self._scope)
end

return CmdrService