--!strict
local ReportText = {}

function ReportText.limit(text: string, maximum: number): string
	local length = utf8.len(text)

	if length and length > maximum then
		return text:sub(1, (utf8.offset(text, maximum + 1) :: number) - 1)
	end

	return text
end

function ReportText.encode(text: string): string
	return (text:gsub(".", function(v)
		return string.format("%02x", string.byte(v))
	end))
end

function ReportText.duration(seconds: number): string
	local total = math.max(0, math.ceil(seconds))
	return `{total // 60}:{string.format("%02d", total % 60)}`
end

return ReportText