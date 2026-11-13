extends Node

const SAVE_PATH: String = "user://save.cfg"
var last_result: Dictionary = {} # Results stay available between scenes.
var unlocked_level: int = 1 # New players start with Breakfast.
var best_stars: Dictionary = {} # Level number → highest earned stars.
var mode: String = "solo" # Current choice: "solo" or "cpu".
var sound_on: bool = true # Saved setting; mutes every sound when false.

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		# Restore progress, keeping the value within our five levels.
		unlocked_level = clampi(
			int(config.get_value("progress", "unlocked_level", 1)), 1, 5
		)
		best_stars = config.get_value("progress", "best_stars", {})
		sound_on = bool(config.get_value("settings", "sound_on", true))

	apply_sound() # Mute or unmute before any music plays.
	print("Saved best stars: ", best_stars) # Check restored ratings.
	print("Highest unlocked meal: ", unlocked_level)


func complete_level(level: int, stars: int) -> void:
	# Preserve the higher of the previous rating and this attempt.
	best_stars[level] = maxi(int(best_stars.get(level, 0)), stars)
	# Clearing the highest unlocked meal opens exactly one more.
	if level == unlocked_level and level < 5:
		unlocked_level += 1
	save_game()


# Flip sound on/off, apply it right away and remember it.
func toggle_sound() -> void:
	sound_on = not sound_on
	apply_sound()
	save_game()


func apply_sound() -> void:
	# Bus 0 is "Master": every sound in the game goes through it.
	AudioServer.set_bus_mute(0, not sound_on)


func save_game() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "unlocked_level", unlocked_level)
	config.set_value("progress", "best_stars", best_stars)
	config.set_value("settings", "sound_on", sound_on)
	if config.save(SAVE_PATH) != OK:
		push_error("Could not save game data.") # Report save failures.
