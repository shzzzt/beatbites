extends Control


func _ready() -> void:
	%Back.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	# Credits is opened from the mode select screen, so go back there.
	get_tree().change_scene_to_file("res://scenes/ui/ModeSelect.tscn")
