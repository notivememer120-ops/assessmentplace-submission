local Constants = {}

Constants.nSettings = {
	nTypes = {
		"Success",
		"Info",
		"Warn",
		"Error",
		"Alert",
		"Default",
	},
	nImages = {
		success = "rbxassetid://74920264774407",
		info = "rbxassetid://112921444805850",
		warn = "rbxassetid://131688329492659",
		error = "rbxassetid://75561042979118",
		alert = "rbxassetid://88496112693331",
		default = "rbxassetid://107537390522145",
	},
	nColors = {
		success = Color3.fromRGB(39, 93, 50),
		info = Color3.fromRGB(61, 100, 148),
		warn = Color3.fromRGB(205, 158, 67),
		error = Color3.fromRGB(153, 59, 39),
		alert = Color3.fromRGB(120, 20, 20),
		default = Color3.fromRGB(50, 50, 50),
	},
	nAlpha = {
		success = 0.5,
		info = 0.5,
		warn = 0.5,
		error = 0.5,
		alert = 0.35,
		default = 0.5,
	},
	nSounds = {
		success = "Success",
		info = "Info",
		warn = "Warn",
		error = "Error",
		alert = "Alert",
		default = "Default",
	},
}

Constants.animSettings = TweenInfo.new(
	1/3,
	Enum.EasingStyle.Quart,
	Enum.EasingDirection.InOut,
	0,
	false,
	0
)

Constants.nFont = Enum.Font.GothamBold
Constants.yFade = 0.5
Constants.yFadeEnd = 0.3
Constants.screenRes = 1080

Constants.device = {
	Mobile = {
		MinTextSize = 14,
		MaxTextSize = 24,
		ImageSize = 26,
		Padding = 10,
		WidthPercentage = 0.3,
		MaxWidth = 250,
		Duration = 4,
		CornerRadius = 8,
		StrokeThickness = 3,
		ScrollBarThickness = 4,
	},
	Desktop = {
		MinTextSize = 24,
		MaxTextSize = 34,
		ImageSize = 36,
		Padding = 16,
		WidthPercentage = 0.3,
		MaxWidth = 500,
		Duration = 3,
		CornerRadius = 12,
		StrokeThickness = 3,
		ScrollBarThickness = 6,
	},
}

return Constants