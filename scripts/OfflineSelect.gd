extends Control


func _ready() -> void:
	# Each button supplies its own mode to the same function.
	%Solo.pressed.connect(_choose_mode.bind("solo"))
	%CPU.pressed.connect(_choose_mode.bind("cpu"))
	%Endless.pressed.connect(_on_endless_pressed)
	%Back.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/ModeSelect.tscn")


func _on_endless_pressed() -> void:
	GameState.mode = "endless"
	get_tree().change_scene_to_file("res://scenes/ui/EndlessSelect.tscn")


func _choose_mode(selected_mode: String) -> void:
	GameState.mode = selected_mode # Remember the choice between scenes.
	print("Offline mode: ", GameState.mode) # Verify our selection.
	get_tree().change_scene_to_file("res://scenes/ui/LevelSelect.tscn")
