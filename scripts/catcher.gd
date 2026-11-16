class_name Catcher
extends Node2D
# The axolotl. Put a finger anywhere on the screen and slide it: the axolotl
# slides the same distance (like dragging it). A tap without sliding does nothing.
# The lane it is in is whichever lane column its center is over.

var lane: int = 1 # 0 = leftmost lane.
var lane_count: int = 3 # Set by the level with setup().
# Sprite size per lane count, so the axolotl fits its lane (whole-number scales).
const SCALE_FOR_LANES: Dictionary = {3: 6, 4: 5, 5: 4}


func _ready() -> void:
	setup(lane_count)


# Level.gd calls this once it knows how many lanes the meal has.
func setup(count: int) -> void:
	lane_count = count
	var pixel_scale: int = SCALE_FOR_LANES.get(count, 4)
	$Sprite2D.scale = Vector2(pixel_scale, pixel_scale)
	set_lane(floori((count - 1) / 2.0)) # Middle lane (left-middle when the count is even).


func lane_width() -> float:
	return get_viewport_rect().size.x / lane_count


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		# relative = how far the finger moved since the last drag event.
		slide_to(position.x + event.relative.x)
	elif event is InputEventScreenTouch and not event.pressed:
		set_lane(lane) # Finger lifted: settle neatly in the middle of the lane.
	elif event.is_action_pressed("ui_left"):
		set_lane(lane - 1) # Keyboard, for testing on a PC.
	elif event.is_action_pressed("ui_right"):
		set_lane(lane + 1)


# Follow the finger smoothly, but never past the outer lane centers.
func slide_to(x: float) -> void:
	var half: float = lane_width() / 2.0
	position.x = roundf(clampf(x, half, get_viewport_rect().size.x - half))
	lane = clampi(int(position.x / lane_width()), 0, lane_count - 1)


func set_lane(new_lane: int) -> void:
	lane = clampi(new_lane, 0, lane_count - 1)
	# Move horizontally to that column's center, rounded to a pixel.
	position.x = roundf((lane + 0.5) * lane_width())
