class_name FallingFood # Lets other scripts recognize this node type.
extends Node2D
signal judgment_made(result: String) # Tell the level what happened.

var arrival_time: float = 0.0 # When this food should reach the catcher.
var lane: int = 0 # Which of the three lanes it belongs to.
var judged: bool = false # This food remembers its own judgment state.
const BAD_TEXTURE = preload("res://assets/art/bad_apple.png")
var is_bad: bool = false # Whether this particular food is rotten.

func update_from_song(time: float, width: float) -> void:
	# Every food takes three seconds to reach the catch line.
	var progress: float = (time - (arrival_time - 3.0)) / 3.0
	visible = not judged and progress >= 0.0 and progress <= 1.2

	var lane_width: float = width / 3.0
	position.x = (lane + 0.5) * lane_width # Center of this food's lane.
	position.y = lerpf(-96.0, 960.0, progress) # Audio-controlled height.

func judge_catch(time: float, catcher_lane: int) -> void:
	if judged or time < arrival_time:
		return # Wait for arrival; never judge twice.

	var lateness: float = time - arrival_time
	
	# Rotten food reports different outcomes from good food.
	if is_bad:
		if lateness > 0.16:
			judged = true
			hide()
			judgment_made.emit("AVOIDED") # Safely passed the catcher.
		elif catcher_lane == lane:
			judged = true
			hide()
			judgment_made.emit("HIT_BAD") # Caught rotten food.
		return # Skip the normal PERFECT / GOOD / MISS rules.
	
	var result: String = ""

	if lateness > 0.16:
		result = "MISS" # The catch window has ended.
	elif catcher_lane != lane:
		return # Allow time to move into this food's lane.
	elif lateness <= 0.06:
		result = "PERFECT" # Catcher was ready on time.
	else:
		result = "GOOD" # Catcher arrived slightly late.

	judged = true # Remember this food's result.
	hide() # Remove its artwork immediately.
	judgment_made.emit(result) # Send the result to the level.
	
func make_rotten() -> void:
	# Used by the online attack: a good food turns rotten mid-song.
	is_bad = true
	$Sprite2D.texture = BAD_TEXTURE
	queue_redraw() # Add the green warning box.


func _ready() -> void:
	if is_bad:
		# Change only this instance's sprite.
		$Sprite2D.texture = BAD_TEXTURE


# Rotten food gets a pale green box with a dashed green border (mockup 05),
# so it's easy to spot and dodge. _draw() paints behind the Sprite2D child.
func _draw() -> void:
	if not is_bad:
		return
	const HALF: float = 64.0 # Box is 128×128 around the 96×96 sprite.
	const GREEN := Color("#8FD14F")
	draw_rect(Rect2(-HALF, -HALF, HALF * 2, HALF * 2), Color("#F1FBE6"))
	var x: float = -HALF
	while x < HALF: # Top and bottom dashes.
		draw_rect(Rect2(x, -HALF, 12, 6), GREEN)
		draw_rect(Rect2(x, HALF - 6, 12, 6), GREEN)
		x += 20
	var y: float = -HALF
	while y < HALF: # Left and right dashes.
		draw_rect(Rect2(-HALF, y, 6, 12), GREEN)
		draw_rect(Rect2(HALF - 6, y, 6, 12), GREEN)
		y += 20
