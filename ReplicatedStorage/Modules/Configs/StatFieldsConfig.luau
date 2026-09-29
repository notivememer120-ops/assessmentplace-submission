local StatFields = {}

StatFields.Fields = {
	TimesJoined = "timesJoined",
	Playtime = "playtime",
	Cash = "cash",
} :: {[string]: string}

StatFields.FieldToLabel = {
	timesJoined = "TimesJoined",
	playtime = "Playtime",
	cash = "Cash",
} :: {[string]: string}

StatFields.AdminFields = {"timesJoined", "playtime", "cash"}

return StatFields