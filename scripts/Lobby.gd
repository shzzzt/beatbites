extends Control


func _ready() -> void:
	$Content/Back.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	# Return to the Offline / Online choice.
	get_tree().change_scene_to_file("res://scenes/ui/ModeSelect.tscn")
