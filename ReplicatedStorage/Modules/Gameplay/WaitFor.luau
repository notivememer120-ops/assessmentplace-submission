--!strict
local RunService = game:GetService("RunService")
local rep = game:GetService("ReplicatedStorage")
local Logger = require(rep.Modules.Imported.Utility.Logger)
local side = if RunService:IsServer() then "Server" else "Client"

local WaitFor = {}

local serverTimeout = if RunService:IsStudio() then 10 else 20
local clientTimeout = if RunService:IsStudio() then 30 else 90

local function defaultTimeout()
	return RunService:IsClient() and clientTimeout or serverTimeout
end

function WaitFor:get(parent: Instance, name: string, timeout: number?): Instance
	timeout = timeout or defaultTimeout()

	local path = `{parent:GetFullName()}.{name}`
	local caller = debug.traceback("", 2)
	local t0 = os.clock()
	local finish = Logger.begin("wait", path)
	local child = parent:WaitForChild(name, timeout)
	
	if not child then
		warn(`[{side}] WaitFor: {path} missing after {string.format("%.2f", os.clock() - t0)}s (timeout {timeout}s), still waiting\n{Logger.context()}\nWait caller:\n{caller}`)

		child = parent:WaitForChild(name)
	end

	finish()

	return child :: Instance
end

function WaitFor:chain(parent: Instance, names: {string}, timeout: number?): Instance
	local current = parent

	for _, name in names do
		current = self:get(current, name, timeout)
	end

	return current
end

return WaitFor