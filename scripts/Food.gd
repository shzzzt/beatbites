class_name FallingFood # Lets other scripts recognize this node type.
extends Node2D
signal judgment_made(result: String) # Tell the level what happened.

var arrival_time: float = 0.0 # When this food should reach the catcher.
var lane: int = 0 # Which lane it belongs to (0 = leftmost).
var lane_count: int = 3 # How many lanes this level has (set by the level).
var judged: bool = false # This food remembers its own judgment state.
var is_bad: bool = false # Whether this particular food is rotten.
var variant: int = 0 # Which picture to use (set by the level before add_child).

# All food pictures (16×16, shown ×6). The first good foods line up with
# their rotten versions: apple → rotten apple, banana → rotten banana.
const GOOD_TEXTURES: Array[Texture2D] = [
	preload("res://assets/art/good_apple.png"),
	preload("res://assets/art/good_banana.png"),
	preload("res://assets/art/good_blueberry.png"),
	preload("res://assets/art/good_donut.png"),
	preload("res://assets/art/good_candy.png"),
	preload("res://assets/art/good_fries.png"),
	preload("res://assets/art/good_icecream.png"),
	preload("res://assets/art/good_bepsi.png"),
]
const BAD_TEXTURES: Array[Texture2D] = [
	preload("res://assets/art/bad_apple.png"),
	preload("res://assets/art/bad_banana.png"),
	preload("res://assets/art/bad_juice.png"),
	preload("res://assets/art/bad_fish.png"),
]

func update_from_song(time: float, width: float) -> void:
	# Every food takes three seconds to reach the catch line.
	var progress: float = (time - (arrival_time - 3.0)) / 3.0
	visible = not judged and progress >= 0.0 and progress <= 1.2

	var lane_width: float = width / lane_count
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
	update_texture()


func _ready() -> void:
	update_texture()


# Show the picture that matches this food's variant and rotten state.
# Changing the texture only affects this one instance.
func update_texture() -> void:
	var pictures: Array[Texture2D] = BAD_TEXTURES if is_bad else GOOD_TEXTURES
	$Sprite2D.texture = pictures[variant % pictures.size()]
