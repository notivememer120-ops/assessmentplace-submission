--!nolint
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local VRService = game:GetService("VRService")
local TextService = game:GetService("TextService")

local function getCharacterSize(characterCodepoint)
	return TextService:GetTextSize(utf8.char(characterCodepoint), 16, Enum.Font.SourceSans, Vector2.new(1000, 1000))
end

local invalidCharacterSize = getCharacterSize(0xFFFF)
local function isValidCharacter(characterCodepoint)
	local characterSize = getCharacterSize(characterCodepoint)
	return characterSize ~= invalidCharacterSize
end

return function()
	local RobloxVersion = version()
	local ButtonSelectImage = UserInputService:GetImageForKeyCode(Enum.KeyCode.ButtonSelect):lower()

	local isDesktopClient = RobloxVersion:find("^0%.") ~= nil
	local isConsoleClient = GuiService:IsTenFootInterface() and RobloxVersion:find("^1%.") ~= nil
	local isMobileClient = RobloxVersion:find("^2%.") ~= nil
	local hasVRHeadset = UserInputService.VREnabled and VRService.VREnabled
	local isWindowsClient = GuiService.IsWindows
	local hasAppleCharacter = isValidCharacter(0xF8FF)

	if isConsoleClient then
		local hasXBoxController = ButtonSelectImage:find("xbox") ~= nil
		local hasPS4Controller = ButtonSelectImage:find("ps4") ~= nil
		local hasPS5Controller = ButtonSelectImage:find("ps5") ~= nil

		if hasXBoxController or isWindowsClient then
			return Enum.Platform.XBoxOne
		elseif hasPS4Controller then
			return Enum.Platform.PS4
		elseif hasPS5Controller then
			return Enum.Platform.PS5
		end
	elseif isMobileClient then
		if isWindowsClient then
			return Enum.Platform.UWP
		elseif hasVRHeadset then
			return Enum.Platform.MetaOS
		elseif hasAppleCharacter then
			return Enum.Platform.IOS
		elseif not UserInputService.TouchEnabled then
			return Enum.Platform.Linux -- Sober (Linux)?
		else
			return Enum.Platform.Android
		end
	elseif isDesktopClient then
		if isWindowsClient then
			return Enum.Platform.Windows
		else
			return Enum.Platform.OSX
		end
	end

	return Enum.Platform.None
end