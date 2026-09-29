local rep = game:GetService("ReplicatedStorage")

local BigNum = require(rep.Modules.Imported.Utility.BigNum)

local CashFormat = {}

function CashFormat.format(amount: (number | string)?): string
	if amount == nil then
		return "$0"
	end

	local decimalStr: string
	
	if type(amount) == "number" then
		decimalStr = string.format("%.0f", amount)
	else
		decimalStr = amount

		if decimalStr == "" then
			decimalStr = "0"
		end
	end

	local asNum = tonumber(decimalStr)
	
	if asNum and asNum < 1000 then
		return `${math.floor(asNum)}`
	end

	local bn = BigNum.stringToNumber(decimalStr)
	
	return `${BigNum.getShort(bn)}`
end

return CashFormat