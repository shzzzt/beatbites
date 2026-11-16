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
# VS CPU / Online: power foods. power_kind is "" (normal food) or one of POWERS.
var power_kind: String = ""
# A rotten food thrown onto our field stays hidden until it lands (Level sets this).
var waiting_to_land: bool = false

# Each power: glow color, sparkle color, label under the food.
const POWERS: Dictionary = {
	"rotten": {"glow": Color(0.71, 0.9, 0.54, 0.6), "sparkle": Color("#5E8C2A"), "label": "THROW"},
	"ink": {"glow": Color(0.8, 0.72, 1.0, 0.65), "sparkle": Color("#5B4494"), "label": "INK"},
	"shield": {"glow": Color(0.75, 0.89, 1.0, 0.7), "sparkle": Color("#2667B0"), "label": "SHIELD"},
	"double": {"glow": Color(1.0, 0.89, 0.48, 0.6), "sparkle": Color("#F2B230"), "label": "x2"},
	"life": {"glow": Color(1.0, 0.72, 0.84, 0.7), "sparkle": Color("#D9468F"), "label": "HEART"},
}
const SPARKLE_LIGHT := Color("#FFF6D6")
const LABEL_FONT = preload("res://assets/fonts/PressStart2P-Regular.ttf")
const LABEL_INK := Color("#3B2A66")

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
	visible = not judged and not waiting_to_land and progress >= 0.0 and progress <= 1.2

	var lane_width: float = width / lane_count
	position.x = (lane + 0.5) * lane_width # Center of this food's lane.
	position.y = lerpf(START_Y, catch_y, progress) # Audio-controlled height.
	if power_kind != "" and visible:
		queue_redraw() # Animate the glow every frame (see _draw).


# Where this food will be at a given song time (used to aim thrown hazards).
func position_at(time: float, width: float) -> Vector2:
	var progress: float = (time - (arrival_time - fall_time)) / fall_time
	return Vector2((lane + 0.5) * width / lane_count, lerpf(START_Y, catch_y, progress))

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
	
# A thrown rotten food just landed on our field: show it with a little "pop"
# (bigger for a moment, then back to ×6; whole-number scales only).
func land() -> void:
	waiting_to_land = false
	var sprite: Sprite2D = $Sprite2D
	sprite.scale = Vector2(9, 9)
	create_tween().tween_property(sprite, "scale", Vector2(6, 6), 0.2)


# Power food: a pulsing colored glow, four sparkles circling it, and a small
# label underneath saying which power it is. _draw() paints behind the Sprite2D.
func _draw() -> void:
	if power_kind == "":
		return
	var style: Dictionary = POWERS[power_kind]
	var seconds: float = Time.get_ticks_msec() / 1000.0
	draw_circle(Vector2.ZERO, 60.0 + 6.0 * sin(seconds * 8.0), style["glow"])
	for i in 4:
		var angle: float = seconds * 2.5 + i * TAU / 4.0
		var spot: Vector2 = (Vector2.RIGHT.rotated(angle) * 64.0).round()
		# A pixel "plus" sparkle: one tall and one wide rectangle.
		draw_rect(Rect2(spot.x - 3, spot.y - 9, 6, 18), style["sparkle"])
		draw_rect(Rect2(spot.x - 9, spot.y - 3, 18, 6), style["sparkle"])
		draw_rect(Rect2(spot.x - 3, spot.y - 3, 6, 6), SPARKLE_LIGHT)
	# Label chip: white box with a colored border and the power's name.
	var text: String = style["label"]
	var text_width: float = LABEL_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var chip := Rect2(-text_width / 2.0 - 8.0, 52.0, text_width + 16.0, 28.0)
	draw_rect(chip, Color.WHITE)
	draw_rect(chip, style["sparkle"], false, 4.0)
	draw_string(LABEL_FONT, Vector2(-text_width / 2.0, 74.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, LABEL_INK)


func _ready() -> void:
	update_texture()


# Show the picture that matches this food's variant and rotten state.
# Changing the texture only affects this one instance.
func update_texture() -> void:
	var pictures: Array[Texture2D] = BAD_TEXTURES if is_bad else GOOD_TEXTURES
	$Sprite2D.texture = pictures[variant % pictures.size()]
