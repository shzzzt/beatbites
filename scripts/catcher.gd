class_name Catcher
extends Node2D

var lane: int = 1 # Lane numbers: 0 = left, 1 = middle, 2 = right.
# Touches below this y belong to the HUD's ◀ ▶ tap zones, not to lane taps.
var ignore_touch_below: float = INF


func _ready() -> void:
	# Start in the middle, using the actual screen width.
	move_to_touch(get_viewport_rect().size.x / 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and event.position.y < ignore_touch_below:
			move_to_touch(event.position.x) # Move on a finger press, not its release.
	elif event is InputEventScreenDrag:
		if event.position.y < ignore_touch_below:
			move_to_touch(event.position.x) # Follow a dragging finger.


func move_to_touch(touch_x: float) -> void:
	var lane_width: float = get_viewport_rect().size.x / 3.0
	# Find the touched column and keep its number between 0 and 2.
	set_lane(int(touch_x / lane_width))


# Move one lane left (-1) or right (+1); used by the HUD tap zones.
func step(direction: int) -> void:
	set_lane(lane + direction)


func set_lane(new_lane: int) -> void:
	var lane_width: float = get_viewport_rect().size.x / 3.0
	lane = clampi(new_lane, 0, 2)
	# Move horizontally to that column's center, rounded to a pixel.
	position.x = roundf((lane + 0.5) * lane_width)
