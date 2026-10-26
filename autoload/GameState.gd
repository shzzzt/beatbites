extends Node

const SAVE_PATH: String = "user://save.cfg"
var last_result: Dictionary = {} # Results stay available between scenes.
var unlocked_level: int = 1 # New players start with Breakfast.


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		# Restore progress, keeping the value within our five levels.
		unlocked_level = clampi(
			int(config.get_value("progress", "unlocked_level", 1)), 1, 5
		)
	print("Highest unlocked meal: ", unlocked_level)


func complete_level(level: int) -> void:
	# Clearing the highest unlocked meal opens exactly one more.
	if level == unlocked_level and level < 5:
		unlocked_level += 1

	var config := ConfigFile.new()
	config.set_value("progress", "unlocked_level", unlocked_level)
	if config.save(SAVE_PATH) != OK:
		push_error("Could not save level progress.") # Report save failures.
