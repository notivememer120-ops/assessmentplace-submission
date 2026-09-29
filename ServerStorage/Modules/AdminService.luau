--!strict
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local runServ = game:GetService("RunService")

local AdminConfig = require(ServerStorage.Modules.AdminConfig)
local AdminPackets = require(ReplicatedStorage.Modules.Packets.AdminPackets)
local StatFields = require(ReplicatedStorage.Modules.Configs.StatFieldsConfig)
local Gamepasses = require(ReplicatedStorage.Modules.Configs.Monetization.Gamepasses)

local AdminService = {}

AdminService.__slittttName = "AdminService"
AdminService.Dependencies = {"BanService", "DataManager", "GamepassService"}

local BanService: typeof(require(script.Parent.BanService))
local DataManager: typeof(require(script.Parent.DataManager))
local GamepassService: typeof(require(script.Parent.GamepassService))

type Args = {
	userId: number | string | nil,
	reason: string?,
	field: string?,
	op: string?,
	value: number | string | nil,
	key: string?,
}

type StatPromise = typeof(require(ReplicatedStorage.Modules.Imported.Backend.Promise).resolve())

type StatMethod = (unknown, Player, number) -> StatPromise

type NullMethod = (unknown, Player) -> StatPromise

local dispatch: {[string]: (Player, Args) -> ()} = {}

local function loudCatch(label: string)
	return function(err: unknown)
		task.spawn(error, `admin {label} write wrong: {tostring(err)}`)
	end
end

local function isAdmin(player: Player): boolean
	return AdminConfig.admins[player.UserId] == true or (AdminConfig.allowStudio and runServ:IsStudio())
end

local function sendSync(player: Player, kind: string, data: unknown)
	AdminPackets.packets.AdminSync.sendTo({
		kind = kind,
		payload = HttpService:JSONEncode(data or {}),
		
	}, player)
end

local function broadcastBansToAdmins()
	local payload = {list = BanService:List()}

	for _, player in Players:GetPlayers() do
		if isAdmin(player) then
			sendSync(player, "bans", payload)
		end
	end
end

local function decode(payload: string): Args
	if not payload or payload == "" then
		return {}
	end

	local s, data = pcall(HttpService.JSONDecode, HttpService, payload)

	if not s or type(data) ~= "table" then
		return {}
	end

	return data
end

local function getPlayerByUserId(userId: number | string | nil): Player?
	userId = tonumber(userId)

	if not userId then
		return nil
	end

	return Players:GetPlayerByUserId(userId :: any)
end

local function hrpOf(player: Player?): BasePart?
	local char = player and player.Character

	if not char then
		return nil
	end

	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function applyStat(target: Player, field: string?, op: string?, value: number | string | nil)
	local label = field and StatFields.FieldToLabel[field]

	if not label then
		return
	end

	value = tonumber(value) or 0

	if op == "set" then
		((DataManager :: unknown) :: {[string]: StatMethod})["Set" .. label](DataManager, target, value):catch(loudCatch(`stat set {field}`))
		
	elseif op == "add" then
		((DataManager :: unknown) :: {[string]: StatMethod})["Add" .. label](DataManager, target, value):catch(loudCatch(`stat add {field}`))
		
	elseif op == "deduct" then
		((DataManager :: unknown) :: {[string]: StatMethod})["Deduct" .. label](DataManager, target, value):catch(loudCatch(`stat deduct {field}`))
		
	elseif op == "null" then
		((DataManager :: unknown) :: {[string]: NullMethod})["Null" .. label](DataManager, target):catch(loudCatch(`stat null {field}`))
	end
end

dispatch.hello = function(caller)
	sendSync(caller, "authed", {})
	sendSync(caller, "bans", {list = BanService:List()})
end

dispatch.kick = function(_caller: Player, args: Args)
	local target = getPlayerByUserId(args.userId)

	if target then
		target:Kick(args.reason or "kicked by admin")
	end
end

dispatch.ban = function(_caller: Player, args: Args)
	local uid = tonumber(args.userId)

	if not uid then
		return
	end

	BanService:Ban(uid, args.reason or "banned by admin")

	broadcastBansToAdmins()
end

dispatch.unban = function(_caller, args)
	local uid = tonumber(args.userId)

	if not uid then
		return
	end

	BanService:Unban(uid)

	broadcastBansToAdmins()
end

dispatch.bring = function(caller, args)
	local target = getPlayerByUserId(args.userId)
	local callerHrp = hrpOf(caller)

	if not target or not callerHrp then
		return
	end

	local targetHrp = hrpOf(target)

	if targetHrp then
		targetHrp.CFrame = callerHrp.CFrame * CFrame.new(3, 0, 0)
	end
end

dispatch.teleportTo = function(caller, args)
	local target = getPlayerByUserId(args.userId)
	local targetHrp = hrpOf(target)
	local callerHrp = hrpOf(caller)

	if not targetHrp or not callerHrp then
		return
	end

	callerHrp.CFrame = targetHrp.CFrame
end

dispatch.stat = function(_caller, args)
	local target = getPlayerByUserId(args.userId)

	if not target then
		return
	end

	applyStat(target, args.field, args.op, args.value)
end

dispatch.wipeData = function(_caller, args)
	local target = getPlayerByUserId(args.userId)

	if not target then
		return
	end

	DataManager:WipeData(target)
end

dispatch.grantPass = function(_caller: Player, args: Args)
	local target = getPlayerByUserId(args.userId)

	if not target or not args.key or type(Gamepasses[args.key]) ~= "table" then
		return
	end

	GamepassService:GrantPass(target, args.key)
end

dispatch.revokePass = function(_caller: Player, args: Args)
	local target = getPlayerByUserId(args.userId)

	if not target or not args.key or type(Gamepasses[args.key]) ~= "table" then
		return
	end

	GamepassService:RevokePass(target, args.key)
end

dispatch.dangerousUnlock = function(caller)
	print(`{caller.Name} ({caller.UserId}) tripped konami unlock`)
end

function AdminService:IsAdmin(player: Player): boolean
	return isAdmin(player)
end

function AdminService.Init(self: {Get: (unknown, string) -> unknown})
	BanService = self:Get("BanService") :: typeof(require(script.Parent.BanService))
	DataManager = self:Get("DataManager") :: typeof(require(script.Parent.DataManager))
	GamepassService = self:Get("GamepassService") :: typeof(require(script.Parent.GamepassService))

	AdminPackets.packets.AdminReq.listen(function(data, player)
		player = player :: Player

		if not isAdmin(player) then
			return
		end

		local handler = dispatch[data.action]

		if not handler then
			warn(`unknown admin action: {data.action}`)
			return
		end

		local args = decode(data.payload)
		local s, err = pcall(handler, player, args)

		if not s then
			warn(`admin action {data.action} blew up: {err}`)
		end
	end)
end

function AdminService:OnPlayerJoined(player: Player)
	if isAdmin(player) then
		task.defer(function()
			sendSync(player, "authed", {})
			sendSync(player, "bans", {list = BanService:List()})
		end)
	end
end

return AdminService