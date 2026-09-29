--!strict
local RateGate = {}
RateGate.__index = RateGate

type State = {_min: number, _last: {[Player]: {[string]: number}}}

export type Gate = typeof(setmetatable({} :: State, RateGate))

function RateGate.new(minInterval: number): Gate
	return setmetatable({_min = minInterval, _last = {}}, RateGate)
end

function RateGate.tooFast(self: Gate, player: Player, kind: string?): boolean
	local key = kind or "_"
	local t = self._last[player]
	
	if not t then
		t = {}
		self._last[player] = t
	end

	local now = os.clock()
	
	if t[key] and now - t[key] < self._min then
		return true
	end

	t[key] = now
	
	return false
end

function RateGate.forget(self: Gate, player: Player)
	self._last[player] = nil
end

return RateGate