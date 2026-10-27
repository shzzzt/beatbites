extends Control


func _ready() -> void:
	# Open the offline picker when this button is pressed.
	$Content/Offline.pressed.connect(_on_offline_pressed)
	
	$Content/Online.pressed.connect(_on_online_pressed)


func _on_offline_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/OfflineSelect.tscn")

func _on_online_pressed() -> void:
	GameState.mode = "online" # Remember the selected game mode.
	get_tree().change_scene_to_file("res://scenes/ui/Lobby.tscn")
