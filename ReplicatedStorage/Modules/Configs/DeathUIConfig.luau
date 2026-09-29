return {
	title = "YOU DIED",
	message = "Oof.",
	causeAttribute = "DeathCause",
	deadAttribute = "Dead",

	messages = {
		admin = "An admin ended your run.",
		reset = "You reset your character.",
	} :: {[string]: string},

	respawn = "RESPAWN",
	respawning = "RESPAWNING...",
	retry = "TRY AGAIN",
	failed = "Couldn't respawn. Please try again.",
	revealTime = 0.3,
	hideTime = 0.18,
	panelSize = Vector2.new(560, 200),
	buttonSize = Vector2.new(240, 50),
	gap = 22,
}