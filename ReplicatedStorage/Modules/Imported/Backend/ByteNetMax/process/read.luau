--!native

local RunService = game:GetService("RunService")

local packetIDs = require(script.Parent.Parent.namespaces.packetIDs)
local queryIDs = require(script.Parent.Parent.namespaces.queryIDs)
local readRefs = require(script.Parent.readRefs)
local types = require(script.Parent.Parent.types)
local bufferWriter = require(script.Parent.bufferWriter)
local diagnostics = require(script.Parent.diagnostics)
local Promise = require(script.Parent.Parent.Parent.Promise)

local alloc = bufferWriter.alloc
local u8 = bufferWriter.u8
local load = bufferWriter.load

local packetRef = packetIDs.ref()
local queryRef = queryIDs.ref()
local freeThread: thread?

local function functionPasser(callback, ...)
	local aquiredThread = freeThread
	freeThread = nil
	callback(...)
	freeThread = aquiredThread
end

local function yielder()
	while true do
		functionPasser(coroutine.yield())
	end
end

local function runListener(callback, listenOnce: boolean, packet, ...)
	if freeThread == nil then
		freeThread = coroutine.create(yielder)
		coroutine.resume(freeThread :: thread)
	end

	task.spawn(freeThread :: thread, callback, ...)
	if listenOnce then
		packet.disconnect(callback)
	end
end

local function runQueryListener(callback, id: number, ...)
	local s
	local result
	s, result = Promise.try(callback, ...):timeout(10):await()

	if not s then
		if Promise.Error.isKind(result, Promise.Error.Kind.TimedOut) then
			error(`[ByteNetMax] Query {id} timed out after 10 seconds:\n{result}`, 0)
		end

		error(`[ByteNetMax] Query {id} listener failed:\n{result}`, 0)
	end

	return result
end

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

return function(incomingBuffer: buffer, references: { [number]: unknown }?, player: Player?, readType: string?, id: number?)
	local length = buffer.len(incomingBuffer)
	local readCursor = 0
	local previousId
	local previousCursor
	local previousLength
	readType = readType or "packet"

	readRefs.set(references)
		
	while readCursor < length do
		local readablePacketOrQuery
		local wireId = buffer.readu8(incomingBuffer, readCursor)
		
		if readType == "packet" then
			readablePacketOrQuery = packetRef[wireId]
		elseif readType == "query" then
			readablePacketOrQuery = queryRef[wireId]
		else
			error("readType not valid.")
		end
				
		if not readablePacketOrQuery then
			error(diagnostics.unknown({
				kind = readType,
				id = wireId,
				envelope = id,
				registered = if readType == "query" then queryRef else packetRef,
				length = length,
				cursor = readCursor,
				references = if references then #references else 0,
				player = player,
				previousId = previousId,
				previousCursor = previousCursor,
				previousLength = previousLength,
			}), 0)
		end
		
		readCursor += 1
		
		local value, valueLength
		
		if readType == "query" then
			if RunService:IsServer() then
				value, valueLength = readablePacketOrQuery.requestReader(incomingBuffer, readCursor)
			elseif RunService:IsClient() then
				value, valueLength = readablePacketOrQuery.responseReader(incomingBuffer, readCursor)
			end
		elseif readType == "packet" then
			value, valueLength = readablePacketOrQuery.reader(incomingBuffer, readCursor)
		end
		
		
		previousId = wireId
		previousCursor = readCursor - 1
		previousLength = valueLength + 1
		readCursor += valueLength

		if readType == "packet" then
			for _, listener in readablePacketOrQuery.getListeners() do
				if typeof(listener) == "table" then
					runListener(listener["OnceCallback"], true, readablePacketOrQuery, value, player)
				elseif typeof(listener) == "function" then
					runListener(listener, false, readablePacketOrQuery, value, player)
				else
					error("Listener type not recognised for packet: " .. typeof(listener))
				end
			end
		elseif readType == "query" then
			if RunService:IsServer() then
				for _, listener in readablePacketOrQuery.getListeners() do
					local response 
					
					if typeof(listener) == "table" then
						readablePacketOrQuery.disconnect(listener)
						response = runQueryListener(listener["OnceCallback"], wireId, value, player)
					elseif typeof(listener) == "function" then
						response = runQueryListener(listener, wireId, value, player)
					else
						error("Listener type not recognised for query: " .. typeof(listener))
					end
					
					local func = create()
					func = load(func)
					
					alloc(1)
					u8(id)
					readablePacketOrQuery.responseWriter(response)
					
					func = bufferWriter.export()
										
					if func.cursor > 0 then
						local dumpBuffer, reference = dump(func)
												
						return dumpBuffer, reference
					end
				end	
			elseif RunService:IsClient() then
				return value
			end
		end
	end
end