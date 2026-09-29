-- ModuleScript in ServerScriptService

local Promise = require(script.Parent.Promise)

local TaskQueue = {}
TaskQueue.__index = TaskQueue

function TaskQueue.new(onFlush, timeout)
	assert(type(onFlush) == "function", "TaskQueue.new expects a flush callback")
	if timeout == nil then
		timeout = 10
	end
	assert(type(timeout) == "number" and timeout > 0 and timeout < math.huge, "TaskQueue timeout must be a positive finite number")

	local self = setmetatable({}, TaskQueue)
	self._queue = {}
	self._flushing = false
	self._scheduled = nil
	self._destroyed = false
	self._onFlush = onFlush
	self._timeout = timeout
	return self
end

function TaskQueue:_schedule()
	if self._destroyed or self._flushing or self._scheduled or #self._queue == 0 then
		return
	end

	self._scheduled = task.defer(function()
		self._scheduled = nil
		local batch = self._queue
		local onFlush = self._onFlush
		self._queue = {}
		self._flushing = true

		local s
		local err
		s, err = Promise.new(function(resolve, reject, onCancel)
			local thread = task.defer(function()
				local s
				local err
				s, err = xpcall(onFlush, function(err)
					return debug.traceback(tostring(err), 2)
				end, batch)

				if s then
					resolve()
				else
					reject(err)
				end
			end)

			onCancel(function()
				task.cancel(thread)
			end)
		end):timeout(self._timeout):await()

		self._flushing = false
		self:_schedule()

		if not s then
			error(`[TaskQueue] Flush failed:\n{err}`, 0)
		end
	end)
end

function TaskQueue:Add(object)
	assert(not self._destroyed, "Cannot add to a destroyed TaskQueue")
	assert(object ~= nil, "TaskQueue:Add expects a non-nil item")

	table.insert(self._queue, object)
	self:_schedule()
end

function TaskQueue:Size()
	return #self._queue
end

function TaskQueue:IsEmpty()
	return #self._queue == 0
end

function TaskQueue:Clear()
	if self._scheduled then
		task.cancel(self._scheduled)
		self._scheduled = nil
	end

	table.clear(self._queue)
end

function TaskQueue:Destroy()
	self._destroyed = true
	self:Clear()
	self._onFlush = nil
end

return TaskQueue