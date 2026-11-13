extends Control
# Title screen: tap anywhere to start. Sound and Credits live on the
# mode select screen, as in the mockup.

var starting: bool = false # Taps can arrive as touch + mouse; start once.


func _ready() -> void:
	# The root Control receives every tap because all its children ignore input.
	gui_input.connect(_on_gui_input)

	# Gently blink "TAP TO START" forever. A Tween created by this node is
	# freed automatically when the scene changes.
	var blink: Tween = create_tween().set_loops()
	blink.tween_property(%TapRow, "modulate:a", 0.35, 0.6)
	blink.tween_property(%TapRow, "modulate:a", 1.0, 0.6)


func _on_gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if tapped:
		start_game()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		start_game() # Enter/Space also work when testing on a PC.


func start_game() -> void:
	if starting:
		return
	starting = true
	get_tree().change_scene_to_file("res://scenes/ui/ModeSelect.tscn")
