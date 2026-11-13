extends Control


func _ready() -> void:
	$Content/Play.pressed.connect(_on_play_pressed)
	$Content/Sound.pressed.connect(_on_sound_pressed)
	$Content/Credits.pressed.connect(_on_credits_pressed)
	update_sound_button()


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/ModeSelect.tscn")


func _on_sound_pressed() -> void:
	GameState.toggle_sound() # Saved, so it survives closing the app.
	update_sound_button()


func _on_credits_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/Credits.tscn")


func update_sound_button() -> void:
	$Content/Sound.text = "SOUND: ON" if GameState.sound_on else "SOUND: OFF"
