extends Control


func _ready() -> void:
	# Each button supplies its own mode to the same function.
	$Content/Solo.pressed.connect(_choose_mode.bind("solo"))
	$Content/CPU.pressed.connect(_choose_mode.bind("cpu"))


func _choose_mode(selected_mode: String) -> void:
	GameState.mode = selected_mode # Remember the choice between scenes.
	print("Offline mode: ", GameState.mode) # Verify our selection.
	get_tree().change_scene_to_file("res://scenes/ui/LevelSelect.tscn")
