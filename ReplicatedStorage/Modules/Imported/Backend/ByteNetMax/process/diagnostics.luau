local rep = game:GetService("ReplicatedStorage")
local runServ = game:GetService("RunService")
local httpServ = game:GetService("HttpService")

local Logger = require(rep.Modules.Imported.Utility.Logger)

local diagnostics = {}

function diagnostics.unknown(ctx)
	local side = if runServ:IsServer() then "server" else "client"
	local field = if ctx.kind == "query" then "queries" else "packets"
	local names = {}
	local namespaces = {}
	local expected = {}
	local folder = rep:FindFirstChild("BytenetStorage")

	if folder then
		for _, v in folder:GetChildren() do
			if not v:IsA("StringValue") then
				continue
			end

			local s, data = pcall(httpServ.JSONDecode, httpServ, v.Value)

			if not s or type(data) ~= "table" or type(data[field]) ~= "table" then
				table.insert(namespaces, `{v.Name}: metadata empty or invalid`)
				continue
			end

			local total = 0
			local registered = 0
			local missing = {}

			for k, id in data[field] do
				local name = `{v.Name}.{k}`
				total += 1
				names[id] = name

				if ctx.registered[id] then
					registered += 1
				else
					table.insert(missing, `{id}={name}`)
				end

				if id == ctx.id then
					table.insert(expected, name)
				end
			end

			table.sort(missing)
			table.insert(namespaces, `{v.Name}: {registered}/{total} registered; missing [{table.concat(missing, ", ")}]`)
		end
	end

	local ids = {}

	for id in ctx.registered do
		table.insert(ids, id)
	end

	table.sort(ids)
	table.sort(namespaces)
	table.sort(expected)

	local known = {}

	for _, id in ids do
		table.insert(known, `{id}={names[id] or "name unavailable"}`)
	end

	local sender = if ctx.player then `{ctx.player.Name} ({ctx.player.UserId})` else "server"
	local previous = if ctx.previousId then `{ctx.previousId}={names[ctx.previousId] or "name unavailable"}, offset={ctx.previousCursor}, consumed={ctx.previousLength}` else "none"
	local advertised = if #expected > 0 then table.concat(expected, ", ") else "not present in replicated metadata"
	local published = if #namespaces > 0 then table.concat(namespaces, "\n") else "none available"

	return table.concat({
		`[ByteNetMax][{side}] Unknown {ctx.kind} ID {ctx.id}`,
		`Advertised name: {advertised}; registered locally: false`,
		`Sender: {sender}; query envelope: {tostring(ctx.envelope)}`,
		`Buffer: {ctx.length} bytes; cursor: {ctx.cursor}; remaining: {ctx.length - ctx.cursor}; references: {ctx.references}`,
		`Previous decoded entity: {previous}`,
		`Local registry ({#known}): [{table.concat(known, ", ")}]`,
		`Replicated namespaces:\n{published}`,
		Logger.context(),
		debug.traceback("Decoder stack:", 2),
	}, "\n")
end

return diagnostics