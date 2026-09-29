--!strict
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local shortAttribute = "ServerRegion"
local fullAttribute = "ServerRegionFull"
local ipFetchUrl = "https://ipconfig.io/json"

local prefixToRegion = {
	["13.244.107"] = {short = "ZA/WC", long = "South Africa, Western Cape, Cape Town"},
	["16.28.85"] = {short = "ZA/WC", long = "South Africa, Western Cape, Cape Town"},

	-- NA
	["13.128.248"] = {short = "US/VA", long = "USA, Northern Virginia"},
	["107.180.197"] = {short = "US/CA", long = "USA, California"},
	["128.116.115"] = {short = "US/WA", long = "USA, Washington, Seattle"},
	["128.116.116"] = {short = "US/CA", long = "USA, California, Los Angeles"},
	["128.116.1"] = {short = "US/CA", long = "USA, California, Los Angeles"},
	["128.116.63"] = {short = "US/CA", long = "USA, California, Los Angeles"},
	["128.116.117"] = {short = "US/CA", long = "USA, California, San Jose"},
	["209.206.42"] = {short = "US/CA", long = "USA, California, San Jose"},
	["209.206.43"] = {short = "US/CA", long = "USA, California, San Jose"},
	["128.116.95"] = {short = "US/TX", long = "USA, Texas, Dallas"},
	["128.116.101"] = {short = "US/IL", long = "USA, Illinois, Chicago"},
	["128.116.48"] = {short = "US/IL", long = "USA, Illinois, Chicago"},
	["128.116.22"] = {short = "US/GA", long = "USA, Georgia, Atlanta"},
	["128.116.99"] = {short = "US/GA", long = "USA, Georgia, Atlanta"},
	["128.116.45"] = {short = "US/FL", long = "USA, Florida, Miami"},
	["128.116.127"] = {short = "US/FL", long = "USA, Florida, Miami"},
	["128.116.102"] = {short = "US/VA", long = "USA, Virginia, Ashburn"},
	["128.116.53"] = {short = "US/VA", long = "USA, Virginia, Ashburn"},
	["128.116.56"] = {short = "US/VA", long = "USA, Virginia, Ashburn"},
	["128.116.11"] = {short = "US/VA", long = "USA, Virginia, Leesburg"},
	["128.116.32"] = {short = "US/NY", long = "USA, New York, NYC"},

	-- SA
	["128.116.86"] = {short = "BR/SP", long = "Brazil, São Paulo, São Paulo"},

	-- EU
	["128.116.33"] = {short = "GB/ENG", long = "UK, England, London"},
	["128.116.119"] = {short = "GB/ENG", long = "UK, England, London"},
	["128.116.21"] = {short = "NL/NH", long = "Netherlands, North Holland, Amsterdam"},
	["128.116.4"] = {short = "FR/IDF", long = "France, Île-de-France, Paris"},
	["128.116.122"] = {short = "FR/IDF", long = "France, Île-de-France, Paris"},
	["128.116.13"] = {short = "FR/IDF", long = "France, Île-de-France, Paris"},
	["128.116.5"] = {short = "DE/HE", long = "Germany, Hesse, Frankfurt"},
	["128.116.44"] = {short = "DE/HE", long = "Germany, Hesse, Frankfurt"},
	["128.116.123"] = {short = "DE/HE", long = "Germany, Hesse, Frankfurt"},
	["128.116.31"] = {short = "PL/MZ", long = "Poland, Mazovia, Warsaw"},
	["128.116.124"] = {short = "PL/MZ", long = "Poland, Mazovia, Warsaw"},
	["128.116.2"] = {short = "PL/MZ", long = "Poland, Mazovia, Warsaw"},

	-- AS
	["128.116.47"] = {short = "IN/MH", long = "India, Maharashtra, Mumbai"},
	["128.116.104"] = {short = "IN/MH", long = "India, Maharashtra, Mumbai"},
	["128.116.55"] = {short = "JP/13", long = "Japan, Tokyo | Prefecture 13"},
	["128.116.120"] = {short = "JP/13", long = "Japan, Tokyo | Prefecture 13"},
	["128.116.50"] = {short = "SG/SG", long = "Singapore"},
	["128.116.97"] = {short = "SG/SG", long = "Singapore"},
	["128.116.46"] = {short = "SG/SG", long = "Singapore"},
	["128.116.54"] = {short = "SG/SG", long = "Singapore"},
	["128.116.30"] = {short = "HK/HK", long = "Hong Kong (decommissioned)"},
	["128.116.118"] = {short = "HK/HK", long = "Hong Kong (decommissioned)"},
	["128.116.14"] = {short = "HK/HK", long = "Hong Kong"},

	-- OC
	["128.116.51"] = {short = "AU/NSW", long = "Australia, New South Wales, Sydney"},
}

local ServerRegionService = {}
ServerRegionService.__slittttName = "ServerRegionService"

local function prefixOf(ip: string): string?
	local a, b, c = ip:match("^(%d+)%.(%d+)%.(%d+)%.%d+$")

	if not a then return nil end
	
	return `{a}.{b}.{c}`
end

local function stamp(short, long)
	-- set Full first so a client listening only on short never reads stale Full
	workspace:SetAttribute(fullAttribute, long)
	workspace:SetAttribute(shortAttribute, short)
end

function ServerRegionService:Init()
	stamp("?/?", "unknown - region not yet resolved")

	if RunService:IsStudio() then
		stamp("STUDIO", "Roblox Studio (local test session)")
		return
	end

	task.spawn(function()
		local ok, body = pcall(function()
			return HttpService:GetAsync(ipFetchUrl)
		end)

		if not ok then
			warn(`region IP fetch failed: {body}`)
			stamp("?/?", "unknown - HTTP fetch failed (HttpEnabled?)")
			return
		end

		local decoded

		ok, decoded = pcall(HttpService.JSONDecode, HttpService, body)

		if not ok or type(decoded) ~= "table" or not decoded.ip then
			warn(`region IP decode failed or missing ip field: {tostring(body):sub(1, 200)}`)
			stamp("?/?", "unknown - decode failed")
			return
		end

		local prefix = prefixOf(decoded.ip)

		if not prefix then
			warn(`region: unexpected IP shape: {decoded.ip}`)
			stamp("?/?", "unknown - bad IP shape")
			return
		end

		local entry = prefixToRegion[prefix]

		if not entry then
			warn(`unmapped Roblox prefix {prefix}.0/24 (ip={decoded.ip}) - extend prefixToRegion`)
			stamp("?/?", `unknown - Roblox prefix {prefix}.0/24 not in table - please send a screenshot to us!`)
			return
		end

		stamp(entry.short, entry.long)
	end)
end

return ServerRegionService