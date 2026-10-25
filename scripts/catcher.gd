extends Node2D 

var lane: int = 1 # Lane numbers: 0 = left, 1 = middle, 2 = right.


func _ready() -> void:
	# Start in the middle, using the actual screen width.
	move_to_touch(get_viewport_rect().size.x / 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed: # Move on a finger press, not its release.
			move_to_touch(event.position.x)
	elif event is InputEventScreenDrag:
		move_to_touch(event.position.x) # Follow a dragging finger.


func move_to_touch(touch_x: float) -> void:
	var lane_width: float = get_viewport_rect().size.x / 3.0
	# Find the touched column and keep its number between 0 and 2.
	lane = clampi(int(touch_x / lane_width), 0, 2)
	# Move horizontally to that column's center, rounded to a pixel.
	position.x = roundf((lane + 0.5) * lane_width)
