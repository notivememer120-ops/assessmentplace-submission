--!strict
--!optimize 2

--[[
	SimpleFramework v1
	Author: slitttt
	Battle-tested by: "Dress to Impress", "Adopt me!"
	Edited by: Dave
	Edited (again) by: Dave
	
	SETUP (server)
		local Framework = require(ReplicatedStorage.Modules.Framework)
		Framework:AddModules(ServerStorage.Modules)
		Framework:Run():andThen(function()
			print("S✅")
		end)
	
	SETUP (client)
		local Framework = require(ReplicatedStorage.Modules.Framework)
		Framework:AddModules(script.Parent.ClientModules)
		Framework:Run():andThen(function()
			print("C✅")
		end)
	
	MODULE CONTRACT
		local MyModule = {}
		MyModule.__slittttName = "MyModule"
		MyModule.Dependencies = {"OtherModule"}      -- optional
		
		function MyModule:Init()
			-- called in dependency order
			-- can return a Promise for async work
			-- self:Get("OtherModule") works for declared deps
			-- (:Get() of a module whose Init hasn't run yet errors - declare it in Dependencies)
		end
		
		function MyModule:Start()
			-- called after ALL modules Init
			-- can return a Promise
			-- self:Get() works for any module
		end
		
		return MyModule
	
	EVENT BUS
		-- fire from anywhere
		Framework:Fire("EnemySpawned", enemyData)	
	
	LIFECYCLE SIGNALS (on the Framework table)
		Framework.ModuleInitialized : Signal<string>        -- fires per module after Init (or if it has none)
		Framework.ModuleStarted     : Signal<string>        -- fires per module after Start (or if it has none)
		Framework.AllInitialized    : Signal<>              -- fires once, all Inits done
		Framework.AllStarted        : Signal<>              -- fires once, all Starts done

	BOOT WATCHDOG
		Any Init/Start still pending after 10s warns with the stuck module's name
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local runServ = game:GetService("RunService")
local Utility = ReplicatedStorage.Modules.Imported.Utility
local Backend = ReplicatedStorage.Modules.Imported.Backend

local Signal = require(Utility.Signal)
local Promise = require(Backend.Promise)
local Logger = require(Utility.Logger)
local side = if runServ:IsServer() then "Server" else "Client"

local Framework = {}
Framework._modules = {} :: {[string]:any}
Framework._modulePaths = {} :: {[string]:string}
Framework._initOrder = {} :: {any}
Framework._initializedSet = {} :: {[string]:boolean}
Framework._failedModules = {} :: {[string]:boolean}
Framework._failedRequires = nil :: {[string]:any}?
Framework._initialized = false
Framework._started = false
Framework._running = false
Framework._debug = false
Framework._channels = {}::{[string]:any}
Framework._benchmarks = {require={}::{[string]:number}, init={}::{[string]:number}, start={}::{[string]:number}}
Framework.ModuleInitialized = Signal() :: Signal.Signal<string>
Framework.ModuleStarted = Signal() :: Signal.Signal<string>
Framework.AllInitialized = Signal()
Framework.AllStarted = Signal()

function Framework.Add(self: typeof(Framework), moduleTable:any)
	assert(typeof(moduleTable) == "table", "Framework:Add() expects a table, got " .. typeof(moduleTable))
	assert(moduleTable.__slittttName, "Module is missing a .__slittttName field")
	assert(not self._modules[moduleTable.__slittttName], `Duplicate module name: "{moduleTable.__slittttName}"`)
	assert(not self._running, `Cannot add module "{moduleTable.__slittttName}" after :Run() has been called.`)
	assert(moduleTable.Get == nil, `Module "{moduleTable.__slittttName}" already defines "Get", Framework would overwrite it.`)
	assert(moduleTable.On == nil, `Module "{moduleTable.__slittttName}" already defines "On", Framework would overwrite it.`)

	moduleTable._framework = self

	moduleTable.Get = function(_self, name: string): any
		return Framework:Get(name)
	end

	moduleTable.On = function(_self, eventName: string, callback:(...any) -> ()): any
		return Framework:GetChannel(eventName):Connect(callback)
	end

	self._modules[moduleTable.__slittttName] = moduleTable
end

function Framework.AddModules(self: typeof(Framework), folder:Instance)
	for _, v in folder:GetChildren() do
		if not v:IsA("ModuleScript") then
			continue
		end

		local path = v:GetFullName()

		self._modulePaths[v.Name] = path

		local t0 = os.clock()
		local caller = debug.traceback("", 2)
		local thread = coroutine.running()
		local finish = Logger.begin("require", path)
		local watchdog = task.delay(5, function()
			warn(`[{side}] Boot require stalled: {path} after {string.format("%.2f", os.clock() - t0)}s\n{Logger.context()}\nRequire caller:\n{caller}\nSuspended require stack:\n{debug.traceback(thread, "", 0)}`)
		end)

		debug.profilebegin("fw.req:" .. v.Name)

		local s, result = pcall(require, v)

		debug.profileend()
		task.cancel(watchdog)
		finish()

		local ms = (os.clock() - t0) * 1000

		if not s then
			self._benchmarks.require[v.Name] = ms

			local failures = self._failedRequires or {}

			self._failedRequires = failures
			failures[v.Name] = result
			
			warn(`[{side}] Failed to require {path} after {string.format("%.2f", ms / 1000)}s: {result}\n{Logger.context()}\nRequire caller:\n{caller}`)
			continue
		end

		if typeof(result) ~= "table" or not result.__slittttName then
			self._benchmarks.require[v.Name] = ms
			continue
		end

		-- key by registration name so require/init/start summaries join cleanly
		self._benchmarks.require[result.__slittttName] = ms
		self._modulePaths[result.__slittttName] = path

		self:Add(result)
	end
end

local function topologicalSort(modules:{[string]:any}, failedRequires:{[string]:any}?): {any}
	local inDegree: {[string]:number} = {}
	local dependents: {[string]:{string}} = {}

	for name in modules do
		inDegree[name] = 0
		dependents[name] = {}
	end

	for name, mod in modules do
		if mod.Dependencies then
			for _, depName in mod.Dependencies do
				if not modules[depName] then
					-- surface the require error here instead of burying it in a warn that scrolled by
					local reqErr = failedRequires and failedRequires[depName]

					if reqErr then
						error(`"{name}" depends on "{depName}", which failed to require: {reqErr}`)
					end

					error(`"{name}" depends on "{depName}", which was never registered.`)
				end

				inDegree[name] = inDegree[name] + 1

				table.insert(dependents[depName], name)
			end
		end
	end

	local queue:{string} = {}

	for name, deg in inDegree do
		if deg == 0 then
			table.insert(queue, name)
		end
	end

	table.sort(queue)

	local sorted: {any} = {}

	while #queue > 0 do
		local current = table.remove(queue, 1) :: string

		table.insert(sorted, modules[current])

		for _, dependent in dependents[current] do
			inDegree[dependent] = inDegree[dependent] - 1

			if inDegree[dependent] == 0 then
				table.insert(queue, dependent)
			end
		end

		table.sort(queue)
	end

	local totalModules = 0

	for _ in modules do totalModules += 1 end

	if #sorted ~= totalModules then
		local stuck = {}

		for name, deg in inDegree do
			if deg > 0 then
				table.insert(stuck, name)
			end
		end

		error(`Circular dependency detected involving: {table.concat(stuck, ", ")}`)
	end

	return sorted
end

function Framework.Get(self: typeof(Framework), name:string): any
	local mod = self._modules[name]

	assert(mod, `Module "{name}" not found. Was it registered?`)

	if self._failedModules[name] then
		error(`:Get("{name}") failed because "{name}" failed to initialize/start or a dependency failed.`)
	end

	if self._running and not self._initialized and not self._initializedSet[name] then
		error(`:Get("{name}") during the Init phase, but "{name}" hasn't initialized yet. Add it to Dependencies to guarantee order.`)
	end

	return mod
end

function Framework.Has(self: typeof(Framework), name:string): boolean
	return self._modules[name] ~= nil
end

function Framework.GetChannel(self: typeof(Framework), name: string)
	if not self._channels[name] then
		self._channels[name] = Signal()
	end

	return self._channels[name]
end

function Framework.Fire(self: typeof(Framework), eventName:string, ...:any)
	local channel = self._channels[eventName]

	if channel then
		channel:Fire(...)
	end
end

local function callLifecycle(mod:any, methodName:string): any
	local fn = mod[methodName]

	if typeof(fn) ~= "function" then
		return Promise.resolve()
	end

	return Promise.try(function()
		local result = (fn :: (any) -> any)(mod)

		if result and Promise.is(result) then
			return result
		end

		return nil
	end)
end

local bootWatchdogSeconds = 10

-- no profilebegin/end in here, await yields and breaks the annotation pair
local function callLifecycleWatched(mod:any, methodName:string): (boolean, any, number, string)
	local path = Framework._modulePaths[mod.__slittttName] or mod.__slittttName
	local t0 = os.clock()
	local caller = debug.traceback("", 2)
	local thread = coroutine.running()
	local finish = Logger.begin(methodName, path)
	local watchdog = task.delay(bootWatchdogSeconds, function()
		warn(`[{side}] Boot stalled: {path}:{methodName}() after {string.format("%.2f", os.clock() - t0)}s\n{Logger.context()}\nLifecycle caller:\n{caller}\nSuspended lifecycle stack:\n{debug.traceback(thread, "", 0)}`)
	end)

	local s, err = callLifecycle(mod, methodName):await()
	local ms = (os.clock() - t0) * 1000

	task.cancel(watchdog)
	finish()

	return s, err, ms, caller
end

function Framework.Run(self: typeof(Framework))
	assert(not self._initialized and not self._running, ":Run() was already called.")

	self._running = true

	return Promise.new(function(resolve, reject)
		self._initOrder = topologicalSort(self._modules, self._failedRequires)

		if self._debug then
			local names = {}

			for i, mod in self._initOrder do
				names[i] = mod.__slittttName
			end

			print("Init order:", table.concat(names, " → "))
		end

		local failedModules = self._failedModules

		for _, mod in self._initOrder do
			local depsFailed = false
			
			if mod.Dependencies then
				for _, depName in mod.Dependencies do
					if failedModules[depName] then
						depsFailed = true
						break
					end
				end
			end

			if depsFailed then
				warn(`[{side}] {self._modulePaths[mod.__slittttName] or mod.__slittttName}:Init() skipped because a dependency failed.`)

				failedModules[mod.__slittttName] = true
				continue
			end

			if typeof(mod.Init) ~= "function" then
				self._initializedSet[mod.__slittttName] = true

				self.ModuleInitialized:Fire(mod.__slittttName)
				continue
			end

			local s, err, ms, caller = callLifecycleWatched(mod, "Init")

			self._benchmarks.init[mod.__slittttName] = ms

			if self._debug then
				print(`Init: {mod.__slittttName} ({string.format("%.1f", ms)}ms)`)
			end

			if not s then
				local path = self._modulePaths[mod.__slittttName] or mod.__slittttName
				local message = `[{side}] {path}:Init() failed after {string.format("%.2f", ms / 1000)}s: {tostring(err)}\n{Logger.context()}\nLifecycle caller:\n{caller}`

				warn(message)
				task.spawn(error, message)

				failedModules[mod.__slittttName] = true
				continue
			end

			self._initializedSet[mod.__slittttName] = true

			self.ModuleInitialized:Fire(mod.__slittttName)
		end

		self._initialized = true

		self.AllInitialized:Fire()

		for _, mod in self._initOrder do
			local depsFailed = false

			if mod.Dependencies then
				for _, depName in mod.Dependencies do
					if failedModules[depName] then
						depsFailed = true
						break
					end
				end
			end

			if depsFailed or failedModules[mod.__slittttName] then
				if depsFailed and not failedModules[mod.__slittttName] then
					warn(`[{side}] {self._modulePaths[mod.__slittttName] or mod.__slittttName}:Start() skipped because a dependency failed.`)

					failedModules[mod.__slittttName] = true
				end

				continue
			end

			if typeof(mod.Start) ~= "function" then
				self.ModuleStarted:Fire(mod.__slittttName)
				continue
			end

			local s, err, ms, caller = callLifecycleWatched(mod, "Start")

			self._benchmarks.start[mod.__slittttName] = ms

			if self._debug then
				print(`Start: {mod.__slittttName} ({string.format("%.1f", ms)}ms)`)
			end

			if not s then
				local path = self._modulePaths[mod.__slittttName] or mod.__slittttName
				local message = `[{side}] {path}:Start() failed after {string.format("%.2f", ms / 1000)}s: {tostring(err)}\n{Logger.context()}\nLifecycle caller:\n{caller}`

				warn(message)
				task.spawn(error, message)

				failedModules[mod.__slittttName] = true
				continue
			end

			self.ModuleStarted:Fire(mod.__slittttName)
		end

		if next(failedModules) or (self._failedRequires and next(self._failedRequires)) then
			local names = {}

			for name in failedModules do table.insert(names, name) end

			if self._failedRequires then
				for k, v in self._failedRequires do
					table.insert(names, `{k} (require: {tostring(v)})`)
				end
			end

			local errMsg = `[{side}] These modules failed to require/initialize/start: {table.concat(names, ", ")}`

			warn(errMsg)
			reject(errMsg)
			return
		end

		self._started = true

		self.AllStarted:Fire()

		if self._debug then
			local function topSummary(label:string, data:{[string]:number})
				local entries: {{name: string, ms: number}} = {}

				for name, ms in data do
					table.insert(entries, {name=name, ms=ms})
				end

				table.sort(entries, function(a: {name: string, ms: number}, b: {name: string, ms: number}) return a.ms > b.ms end)
				print(`top {label}:`)

				for i = 1, math.min(10, #entries) do
					local e = entries[i]

					print(`  {string.format("%6.1f", e.ms)}ms  {e.name}`)
				end
			end

			topSummary("require", self._benchmarks.require)
			topSummary("init", self._benchmarks.init)
			topSummary("start", self._benchmarks.start)
		end

		resolve()
	end)
end

function Framework.GetBenchmarks(self: typeof(Framework))
	return self._benchmarks
end

-- we're NEVER gonna reboot the framework at runtime
-- just saying
-- i redid framework:Run as fireandforget
-- so NO
-- we are NEVER soft-rebooting anything
-- for CRYING OUT LOUD you should IGNORE this function
-- IGNORE IT!!!!!!! I'M BEGGING YOU!!!!!!!
-- # IGNORE
-- # IT
-- i cant believe im typing this in markdown even tho roblox studio doesnt support it
-- IGNORE ITTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
function Framework:Destroy()
	for _, mod in self._initOrder do
		if typeof(mod.Destroy) == "function" then
			local s, err = pcall(mod.Destroy, mod)

			if not s then
				warn(`{mod.__slittttName}:Destroy() failed: {err}`)
			end
		end
	end

	self.ModuleInitialized:Destroy()
	self.ModuleStarted:Destroy()
	self.AllInitialized:Destroy()
	self.AllStarted:Destroy()

	for _, channel in self._channels do
		channel:Destroy()
	end

	table.clear(self._modules)
	table.clear(self._modulePaths)
	table.clear(self._initOrder)
	table.clear(self._initializedSet)
	table.clear(self._channels)
end

return Framework