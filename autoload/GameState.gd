extends Node

const SAVE_PATH: String = "user://save.cfg"
var last_result: Dictionary = {} # Results stay available between scenes.
var unlocked_level: int = 1 # New players start with Breakfast.
var best_stars: Dictionary = {} # Level number → highest earned stars.
var mode: String = "solo" # Current choice: "solo" or "cpu".
var sound_on: bool = true # Saved setting; mutes every sound when false.
var volume: float = 1.0 # Saved master volume, 0.0 (silent) to 1.0 (full).
# Saved audio delay in ms. Positive = the player hears the music late (e.g.
# Bluetooth headphones), so the game clock is shifted back by this much.
var timing_offset_ms: int = 0
const TIMING_OFFSET_LIMIT: int = 200

# Shared meal info for menus and the HUD (index 0 = level 1).
const MEALS: Array[Dictionary] = [
	{"name": "Breakfast", "bpm": 90, "info": "learn to catch"},
	{"name": "Lunch", "bpm": 100, "info": "faster tempo"},
	{"name": "Snack", "bpm": 115, "info": "rotten food!"},
	{"name": "Dinner", "bpm": 125, "info": "side switches"},
	{"name": "Dessert", "bpm": 140, "info": "everything"},
]


func meal_name(level: int) -> String:
	return str(MEALS[clampi(level, 1, 5) - 1]["name"])


# Sum of the best Solo stars for every meal (max 15).
func total_stars() -> int:
	var total: int = 0
	for stars in best_stars.values():
		total += int(stars)
	return total

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		# Restore progress, keeping the value within our five levels.
		unlocked_level = clampi(
			int(config.get_value("progress", "unlocked_level", 1)), 1, 5
		)
		best_stars = config.get_value("progress", "best_stars", {})
		sound_on = bool(config.get_value("settings", "sound_on", true))
		volume = clampf(float(config.get_value("settings", "volume", 1.0)), 0.0, 1.0)
		timing_offset_ms = clampi(int(config.get_value("settings", "timing_offset_ms", 0)),
			-TIMING_OFFSET_LIMIT, TIMING_OFFSET_LIMIT)

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
	# Buses use decibels; linear_to_db turns 0.0-1.0 into dB (1.0 = 0 dB).
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))


func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	apply_sound()
	save_game()


func set_timing_offset(ms: int) -> void:
	timing_offset_ms = clampi(ms, -TIMING_OFFSET_LIMIT, TIMING_OFFSET_LIMIT)
	save_game()


# Start the campaign over: only Breakfast unlocked, no stars. Settings stay.
func reset_progress() -> void:
	unlocked_level = 1
	best_stars = {}
	save_game()


func save_game() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "unlocked_level", unlocked_level)
	config.set_value("progress", "best_stars", best_stars)
	config.set_value("settings", "sound_on", sound_on)
	config.set_value("settings", "volume", volume)
	config.set_value("settings", "timing_offset_ms", timing_offset_ms)
	if config.save(SAVE_PATH) != OK:
		push_error("Could not save game data.") # Report save failures.
