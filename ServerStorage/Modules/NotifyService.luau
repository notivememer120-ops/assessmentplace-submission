--!strict
local rep = game:GetService("ReplicatedStorage")
local runServ = game:GetService("RunService")

local NotifyPackets = require(rep.Modules.Packets.NotifyPackets)

local ServerNotice = NotifyPackets.packets.ServerNotice

type Notice = {
	kind: string?,
	title: string?,
	text: string?,
	count: number?,
	urgent: boolean?,
}

local kindIds: {[string]: number} = {ok = 1, err = 2, info = 3, warn = 4}
local shutdownNoticeSeconds = 5

local function pack(cfg: Notice)
	return {
		kind = (cfg.kind and kindIds[cfg.kind]) or kindIds.info,
		title = cfg.title or "",
		text = cfg.text or "",
		count = cfg.count or 0,
		urgent = cfg.urgent == true,
	}
end

local NotifyService = {}
NotifyService.__slittttName = "NotifyService"

function NotifyService:Init()
	if not runServ:IsStudio() then
		game:BindToClose(function()
			ServerNotice.sendToAll(pack({
				kind = "warn",
				title = "Server restarting",
				text = "Saving your progress. You will rejoin a fresh server shortly.",
				count = shutdownNoticeSeconds,
				urgent = true,
			}))

			task.wait(shutdownNoticeSeconds)
		end)
	end
end

function NotifyService:Send(plr: Player, cfg: Notice)
	ServerNotice.sendTo(pack(cfg), plr)
end

function NotifyService:Broadcast(cfg: Notice)
	ServerNotice.sendToAll(pack(cfg))
end

return NotifyService