extends Control

const SOUND_ON_ICON = preload("res://assets/art/icon_sound_on.png")
const SOUND_OFF_ICON = preload("res://assets/art/icon_sound_off.png")

# "%Name" finds a node marked "Access as Unique Name" anywhere in this scene,
# so moving it into another container doesn't break the path.
@onready var sound_button: Button = %Sound
@onready var stars_label: Label = %Stars


func _ready() -> void:
	%Offline.pressed.connect(_on_offline_pressed)
	%Online.pressed.connect(_on_online_pressed)
	%Settings.pressed.connect(_on_settings_pressed)
	%Credits.pressed.connect(_on_credits_pressed)
	sound_button.pressed.connect(_on_sound_pressed)
	update_sound_icon()

	# Total of the best stars saved for each Solo meal (max 3 × 5 = 15).
	stars_label.text = "%d / 15 stars collected" % GameState.total_stars()


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/Settings.tscn")


func _on_credits_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/Credits.tscn")


func _on_offline_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/OfflineSelect.tscn")

func _on_online_pressed() -> void:
	GameState.mode = "online" # Remember the selected game mode.
	get_tree().change_scene_to_file("res://scenes/ui/Lobby.tscn")


func _on_sound_pressed() -> void:
	GameState.toggle_sound() # Saved, so it survives closing the app.
	update_sound_icon()


func update_sound_icon() -> void:
	sound_button.icon = SOUND_ON_ICON if GameState.sound_on else SOUND_OFF_ICON
	# Screen readers / tooltips get a text description of the icon.
	sound_button.tooltip_text = "Sound on" if GameState.sound_on else "Sound off"
