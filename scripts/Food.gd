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
	
func _ready() -> void:
	if is_bad:
		# Change only this instance's sprite.
		$Sprite2D.texture = BAD_TEXTURE
