-- Tags: Packets

local Packet = require(script.Parent)

local packets = {
	CreateTween = Packet(Packet.NumberU8, Packet.Instance, Packet.Any, Packet.Any),
	StartTween = Packet(Packet.NumberU8, Packet.Any, Packet.Any),
	StopTween = Packet(Packet.NumberU8),
	ResetTween = Packet(Packet.NumberU8),
	DestroyTween = Packet(Packet.NumberU8),
	GetAPIMap = Packet():Response(Packet.Any)
}

packets.GetAPIMap.ResponseTimeout = 30

if game:GetService("RunService"):IsServer() then
	packets.GetAPIMap.OnServerInvoke = function()
		return require(script.Parent.Parent.APIMap)
	end
end

return packets