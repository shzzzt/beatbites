class_name FallingFood # Lets other scripts recognize this node type.
extends Node2D
signal judgment_made(result: String) # Tell the level what happened.

var arrival_time: float = 0.0 # When this food should reach the catcher.
var lane: int = 0 # Which lane it belongs to (0 = leftmost).
var lane_count: int = 3 # How many lanes this level has (set by the level).
var fall_time: float = 2.4 # Seconds from the top to the catcher (set by the level).
var catch_y: float = 1080.0 # Height of the axolotl; food is here exactly on the beat.
const START_Y: float = -96.0 # Just above the top of the screen.
var judged: bool = false # This food remembers its own judgment state.
var is_bad: bool = false # Whether this particular food is rotten.
var variant: int = 0 # Which picture to use (set by the level before add_child).
# VS CPU / Online: catching a power food throws a rotten food at the rival.
var is_power: bool = false
var targeted: bool = false # An incoming attack is already flying at this food.

const GLOW := Color(1.0, 0.89, 0.48, 0.55) # Soft gold circle behind power food.
const SPARKLE := Color("#F2B230")
const SPARKLE_LIGHT := Color("#FFF6D6")

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
	# 0 = just appeared at the top, 1 = at the catch line. Harder meals use a
	# shorter fall_time, so food drops faster and the bites are spaced further apart.
	var progress: float = (time - (arrival_time - fall_time)) / fall_time
	visible = not judged and progress >= 0.0 and progress <= 1.2

	var lane_width: float = width / lane_count
	position.x = (lane + 0.5) * lane_width # Center of this food's lane.
	position.y = lerpf(START_Y, catch_y, progress) # Audio-controlled height.
	if is_power and visible:
		queue_redraw() # Animate the glow every frame (see _draw).

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
	# Used by attacks: a good food turns rotten mid-song.
	is_bad = true
	is_power = false
	update_texture()
	queue_redraw() # Remove the power glow if it had one.
	# Little "pop" so the change is easy to notice (whole-number scales only).
	var sprite: Sprite2D = $Sprite2D
	sprite.scale = Vector2(8, 8)
	create_tween().tween_property(sprite, "scale", Vector2(6, 6), 0.2)


# Power food: a pulsing gold glow with four sparkles circling it.
# _draw() paints behind the Sprite2D child.
func _draw() -> void:
	if not is_power:
		return
	var seconds: float = Time.get_ticks_msec() / 1000.0
	draw_circle(Vector2.ZERO, 60.0 + 6.0 * sin(seconds * 8.0), GLOW)
	for i in 4:
		var angle: float = seconds * 2.5 + i * TAU / 4.0
		var spot: Vector2 = (Vector2.RIGHT.rotated(angle) * 64.0).round()
		# A pixel "plus" sparkle: one tall and one wide rectangle.
		draw_rect(Rect2(spot.x - 3, spot.y - 9, 6, 18), SPARKLE)
		draw_rect(Rect2(spot.x - 9, spot.y - 3, 18, 6), SPARKLE)
		draw_rect(Rect2(spot.x - 3, spot.y - 3, 6, 6), SPARKLE_LIGHT)


func _ready() -> void:
	update_texture()


# Show the picture that matches this food's variant and rotten state.
# Changing the texture only affects this one instance.
func update_texture() -> void:
	var pictures: Array[Texture2D] = BAD_TEXTURES if is_bad else GOOD_TEXTURES
	$Sprite2D.texture = pictures[variant % pictures.size()]
