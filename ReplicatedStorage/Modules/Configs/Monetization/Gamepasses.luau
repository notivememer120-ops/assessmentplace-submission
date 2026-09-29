local Gamepasses: {[string]: any} = {}

function Gamepasses.GetAllPassNames(): {string}
	local names = {}

	for n, v in Gamepasses do
		if type(v) == "table" then
			table.insert(names, n)
		end
	end

	table.sort(names)
	return names
end

return Gamepasses