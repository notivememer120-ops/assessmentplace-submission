local logger = {}
local old_print = print
local old_warn = warn
local pending = {}

function logger.begin(kind, label)
	local entry = {kind = kind, label = label, started = os.clock(), caller = debug.traceback("", 2)}
	pending[entry] = true

	return function()
		pending[entry] = nil
	end
end

function logger.context()
	local entries = {}

	for entry in pending do
		table.insert(entries, entry)
	end

	table.sort(entries, function(a, b)
		return a.started < b.started
	end)

	if #entries == 0 then
		return "Pending work: none recorded"
	end

	local lines = {`Pending work: {#entries}`}

	for i = 1, math.min(#entries, 12) do
		local entry = entries[i]
		table.insert(lines, `{entry.kind}: {entry.label} ({string.format("%.2f", os.clock() - entry.started)}s)\nRequested from:{entry.caller}`)
	end

	return table.concat(lines, "\n")
end

local function arg(...)
	local msg = {}
	
	for i = 1, select('#', ...) do
		msg[i] = tostring(select(i, ...))
	end
	
	return table.concat(msg, '\t')
end

local function trace(start, max)
	local t = {}
	
	for level = start, max do
		local info_s = debug.info(level, 's')
		local info_l = debug.info(level, 'l')
		local info_n = debug.info(level, 'n') or '(anon fn)'
		if not info_s then break end
		t[#t + 1] = `\t\t> called from: '{info_s}' @ $ {info_l} in fn '{info_n}'`
	end
	
	return t
end

function logger.print(...)
	local s = debug.info(2, 's')
	local l = debug.info(2, 'l')
	local n = debug.info(2, 'n') or '(anon fn)'
	local lo = (`{script.Name} | {s} @ $ {l} in {n}`)
	local output = `\n{string.rep('\t', 4)}{arg(...)}`
	local stack = trace(3, 10)
	
	if #stack > 0 then
		output ..= '\n' .. string.rep('\t', 4) .. '-- call stack --\n'
		output ..= string.rep('\t', 4) .. table.concat(stack, '\n' .. string.rep('\t', 4))
	end
	
	old_print(lo, '->', output)
end

function logger.warn(...)
	local s = debug.info(2, 's')
	local l = debug.info(2, 'l')
	local n = debug.info(2, 'n') or '(anon fn)'
	local lo = (`{script.Name} | {s} @ {l} in {n}`)
	local output = `\n{string.rep('\t', 4)}{arg(...)}`
	local stack = trace(3, 10)
	
	if #stack > 0 then
		output ..= '\n' .. string.rep('\t', 4) .. '-- call stack --\n'
		output ..= string.rep('\t', 4) .. table.concat(stack, '\n' .. string.rep('\t', 4))
	end
	
	old_warn(lo, '->', output)
end

return logger