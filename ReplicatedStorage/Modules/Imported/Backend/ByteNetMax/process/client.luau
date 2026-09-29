local RunService = game:GetService("RunService")

local types = require(script.Parent.Parent.types)
local read = require(script.Parent.read)
local bufferWriter = require(script.Parent.bufferWriter)

local alloc = bufferWriter.alloc
local u8 = bufferWriter.u8
local load = bufferWriter.load

local function onClientEvent(receivedBuffer, ref)
	read(receivedBuffer, ref)
end

-- Shared with: src/process/server.luau, src/process/read.luau (Infeasible to split this into another file)
local function create()
	return {
		cursor = 0,
		size = 256,
		references = {},
		buff = buffer.create(256),
	}
end

local function dump(channel: types.channelData): (buffer, { unknown }?)
	local cursor = channel.cursor
	local dumpBuffer = buffer.create(cursor)

	buffer.copy(dumpBuffer, 0, channel.buff, 0, cursor)

	return dumpBuffer, if #channel.references > 0 then channel.references else nil
end
-- No longer shared

local reliable: types.channelData = create()
local unreliable: types.channelData = create()
local funcs: {types.remoteFunctionChannel} = {}

local clientProcess = {}

function clientProcess.sendReliable(id: number, writer: (value: any) -> (), data: { [string]: any })
	reliable = load(reliable)

	alloc(1)
	u8(id)
	writer(data)

	reliable = bufferWriter.export()
end

function clientProcess.sendUnreliable(id: number, writer: (value: any) -> (), data: { [string]: any })
	unreliable = load(unreliable)

	alloc(1)
	u8(id)
	writer(data)

	unreliable = bufferWriter.export()
end

function clientProcess.invoke(id: number, requestWriter: (value: any) -> (), data: {[string]: any}): any
	local func = create()
	func = load(func)

	alloc(1)
	u8(id)
	requestWriter(data)

	func = bufferWriter.export()

	local waitingThread = coroutine.running()
	local result = {
		thread = waitingThread,
		data = func,
		id = id
	}

	table.insert(funcs, result)

	local success, resultDumpBuffer, resultReference = coroutine.yield()

	if not success then
		error("ByteNet Query failed: Server did not respond or an error occurred.")
	end

	local decodedData = read(resultDumpBuffer, resultReference, nil, "query")
	return decodedData
end

function clientProcess.start()	
	task.spawn(function()
		local eventsFolder = script.Parent.Parent:WaitForChild("system")

		local reliableRemote = eventsFolder:WaitForChild("ByteNetReliable")
		reliableRemote.OnClientEvent:Connect(onClientEvent)

		local unreliableRemote = eventsFolder:WaitForChild("ByteNetUnreliable")
		unreliableRemote.OnClientEvent:Connect(onClientEvent)

		local remoteFunction: RemoteFunction = eventsFolder:WaitForChild("ByteNetQuery")

		RunService.Heartbeat:Connect(function()
			-- Again, checking if there's anything in the channel before we send it.
			if reliable.cursor > 0 then
				local b, r = dump(reliable)
				reliableRemote:FireServer(b, r)

				-- effectively clears the channel
				reliable.cursor = 0
				table.clear(reliable.references)
			end

			if unreliable.cursor > 0 then
				local b, r = dump(unreliable)
				unreliableRemote:FireServer(b, r)

				unreliable.cursor = 0
				table.clear(unreliable.references)
			end

			for i=#funcs,1,-1 do
				local func = funcs[i]
				table.remove(funcs, i)

				task.spawn(function()
					if (func.data.cursor > 0) then
						local dumpBuffer, reference = dump(func.data)

						local success, ResultDumpBuffer, ResultReference = pcall(function()
							return remoteFunction:InvokeServer(dumpBuffer, reference, func.id)
						end)

						func.data.cursor = 0
						table.clear(func.data.references)

						if success then
							task.spawn(func.thread, true, ResultDumpBuffer, ResultReference)
						else
							warn("ByteNet Query InvokeServer failed:", ResultDumpBuffer)
							task.spawn(func.thread, false, nil, nil)
						end
					end
				end)
			end
		end)
	end)
end

return clientProcess