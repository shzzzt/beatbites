class_name GameHUD
extends Control
# Gameplay HUD (mockups 05 and 08). Level.gd creates it and calls these
# functions; the HUD never changes game rules, it only shows numbers.
#   Solo:          level name, score, hearts, goal bar
#   VS CPU/Online: YOU vs RIVAL panel + tug bar, and the rotten-food throw
#                  animations (play_throw / play_incoming)

const HEART_TEXTURE = preload("res://assets/art/ui_heart.png")
# ui_heart.png is a white shape, so modulate gives it its exact color.
const FULL_HEART := Color("#FF8FB8")
const EMPTY_HEART := Color("#E3D4FF")
const PINK := Color("#D9468F")
const BLUE := Color("#2667B0")
const LIGHT_BLUE := Color("#C7E6FF")
const LIGHT_PINK := Color("#FFC9E3")
const MUTED := Color("#6B58A0")
const ROTTEN := Color("#B02C6C")
const GREEN := Color("#3E7A12")

const FLIGHT_TIME: float = 0.55 # Seconds a thrown rotten food is in the air.
const PUFF_COLOR := Color(0.56, 0.82, 0.31, 0.8) # Green trail behind it.
const DEBRIS_COLORS: Array[Color] = [
	Color("#8FD14F"), Color("#5E8C2A"), Color("#C9E89E"), Color("#9A5B0C"),
]

var judgment_tween: Tween
var message_tween: Tween
var incoming_tween: Tween
var shake_bases: Dictionary = {} # Control -> its resting position while shaking.


func _ready() -> void:
	_fill_hearts(%YouHearts)
	_fill_hearts(%RivalHearts)


# mode: "solo", "cpu" or "online".
func setup(mode: String, level: int, meal: String) -> void:
	%LevelName.text = "LV %d · %s" % [level, meal.to_upper()]
	%SoloTop.visible = mode == "solo"
	%VersusTop.visible = mode != "solo"
	%RivalName.text = "CPU" if mode == "cpu" else "RIVAL"
	if mode == "online":
		# Show both usernames (shared when the phones connected).
		%YouName.text = GameState.username
		if Net.opponent_name != "":
			%RivalName.text = Net.opponent_name


# --- Numbers ----------------------------------------------------------------

func set_score(value: int) -> void:
	%Score.text = "%05d" % value


func set_lives(lives: int) -> void:
	_show_hearts(%Hearts, lives)


func set_goal(caught: int, goal: int) -> void:
	%GoalCount.text = "%d / %d" % [mini(caught, goal), goal]
	%GoalBar.max_value = goal
	%GoalBar.value = mini(caught, goal)


func set_versus(my_score: int, my_lives: int, opp_score: int, opp_lives: int) -> void:
	%YouScore.text = "%05d" % my_score
	%RivalScore.text = "%05d" % opp_score
	_show_hearts(%YouHearts, my_lives)
	_show_hearts(%RivalHearts, opp_lives)
	# Blue part = your share of the total points; 50/50 before anyone scores.
	var total: int = my_score + opp_score
	%TugBar.value = 0.5 if total == 0 else float(my_score) / total


# --- Throw animations ---------------------------------------------------------
# All positions are in screen pixels (the HUD covers the whole 720×1280 screen,
# the same coordinates the level uses for food and the catcher).

# We caught a power food: a rotten food arcs from our axolotl to the rival's
# side of the panel and splats there.
func play_throw(from: Vector2) -> void:
	_float_text(from + Vector2(0, -130), "THROW!", PINK)
	var target: Vector2 = _center_of(%Rival)
	_launch(from, func() -> Vector2: return target, 320.0, func() -> void:
		_impact(target, "SPLAT!")
		_shake(%VersusPanel)
		_flash(%VersusPanel)
	)


# The rival caught a power food: it flies from their side of the panel down
# onto one of our bites. get_target returns where that bite is right now (it
# keeps falling during the flight); on_hit runs when it lands.
func play_incoming(get_target: Callable, on_hit: Callable) -> void:
	show_incoming()
	var panel: Control = %VersusPanel
	# Wind-up: the panel puffs up for a moment before the throw.
	panel.pivot_offset = panel.size / 2.0
	var wind_up := create_tween()
	wind_up.tween_property(panel, "scale", Vector2(1.08, 1.08), 0.1)
	wind_up.tween_property(panel, "scale", Vector2.ONE, 0.15)
	_launch(_center_of(%Rival), get_target, -160.0, func() -> void:
		var spot: Vector2 = get_target.call()
		on_hit.call()
		_impact(spot, "ROTTEN!")
	)


# Flies a spinning rotten food along a curve and leaves a green trail.
# arc > 0 bends the path upward (a lob); arc < 0 bends it sideways/down.
func _launch(from: Vector2, get_target: Callable, arc: float, on_land: Callable) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = FallingFood.BAD_TEXTURES.pick_random()
	sprite.scale = Vector2(6, 6)
	sprite.position = from
	add_child(sprite)
	var trail: Dictionary = {"last": 0.0} # A Dictionary so the lambda can change it.
	var fly := func(t: float) -> void:
		var end: Vector2 = get_target.call()
		# Quadratic Bezier curve: start → bend point → end.
		var bend: Vector2 = (from + end) / 2.0 + Vector2(arc * 0.35, -absf(arc))
		if arc < 0.0:
			bend = (from + end) / 2.0 + Vector2(arc, 0.0)
		sprite.position = from.lerp(bend, t).lerp(bend.lerp(end, t), t).round()
		sprite.rotation = t * TAU * 1.5 # One and a half spins.
		if t - trail["last"] >= 0.07:
			trail["last"] = t
			_puff(sprite.position)
	var tween := create_tween()
	tween.tween_method(fly, 0.0, 1.0, FLIGHT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		sprite.queue_free()
		on_land.call()
	)


# Splat at a spot: flying pixel debris + floating text.
func _impact(spot: Vector2, text: String) -> void:
	for i in 12:
		var bit := ColorRect.new()
		bit.color = DEBRIS_COLORS[i % DEBRIS_COLORS.size()]
		bit.size = Vector2(12, 12)
		bit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bit.position = spot - bit.size / 2.0
		add_child(bit)
		var direction: Vector2 = Vector2.RIGHT.rotated(i * TAU / 12.0 + randf() * 0.4)
		var tween := create_tween().set_parallel()
		tween.tween_property(bit, "position", bit.position + direction * randf_range(70, 150), 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(bit, "modulate:a", 0.0, 0.45)
		tween.chain().tween_callback(bit.queue_free)
	_float_text(spot + Vector2(0, -70), text, ROTTEN)


# One square of the green trail; fades out by itself.
func _puff(spot: Vector2) -> void:
	var puff := ColorRect.new()
	puff.color = PUFF_COLOR
	puff.size = Vector2(18, 18)
	puff.mouse_filter = Control.MOUSE_FILTER_IGNORE
	puff.position = spot - puff.size / 2.0
	add_child(puff)
	move_child(puff, 0) # Behind the flying food.
	var tween := create_tween()
	tween.tween_property(puff, "modulate:a", 0.0, 0.3)
	tween.tween_callback(puff.queue_free)


# Text that floats up and fades (THROW!, SPLAT!, ROTTEN!).
func _float_text(spot: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.theme_type_variation = &"CardTitle"
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 12)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(360, 48)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keep the text on screen even near the edges.
	label.position = Vector2(clampf(spot.x - 180.0, 0.0, 360.0), spot.y - 24.0)
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 60.0, 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tween.tween_callback(label.queue_free)


# Quick side-to-side wobble.
func _shake(node: Control) -> void:
	if not shake_bases.has(node):
		shake_bases[node] = node.position # Remember where it really belongs.
	var base: Vector2 = shake_bases[node]
	var tween := create_tween()
	for offset in [14.0, -12.0, 9.0, -6.0, 3.0, 0.0]:
		tween.tween_property(node, "position", base + Vector2(offset, 0), 0.04)


# Flash pink-red, then back to normal colors.
func _flash(node: CanvasItem) -> void:
	node.modulate = Color(1.0, 0.55, 0.65)
	create_tween().tween_property(node, "modulate", Color.WHITE, 0.35)


func _center_of(node: Control) -> Vector2:
	# Our position on screen minus the HUD's own, so it works in HUD coordinates.
	return node.get_global_rect().get_center() - get_global_rect().position


# --- Pop-ups ----------------------------------------------------------------

func show_incoming() -> void:
	%Incoming.show()
	if incoming_tween:
		incoming_tween.kill() # A newer attack restarts the 1.5 s display.
	incoming_tween = create_tween()
	incoming_tween.tween_interval(1.5)
	incoming_tween.tween_callback(%Incoming.hide)


# Shows PERFECT! / GOOD! / MISS / ROTTEN! / DODGED! in the middle, plus the
# combo underneath, then fades them out.
func show_judgment(result: String, combo: int) -> void:
	var judgment: Label = %Judgment
	var combo_label: Label = %Combo
	judgment.text = result if result.ends_with("!") else result + "!"
	if result == "MISS":
		judgment.text = "MISS"

	var color: Color = MUTED
	var shadow: Color = Color(0, 0, 0, 0)
	match result:
		"PERFECT":
			color = PINK
			shadow = LIGHT_BLUE
		"GOOD":
			color = BLUE
			shadow = LIGHT_PINK
		"ROTTEN!":
			color = ROTTEN
		"DODGED!":
			color = GREEN
	judgment.add_theme_color_override("font_color", color)
	judgment.add_theme_color_override("font_shadow_color", shadow)

	combo_label.text = "x%d COMBO" % combo
	var show_combo: bool = combo >= 2 # A combo of 1 isn't worth shouting about.

	if judgment_tween:
		judgment_tween.kill()
	judgment.modulate.a = 1.0
	combo_label.modulate.a = 1.0 if show_combo else 0.0
	judgment.position.y = 740.0 + 12.0
	judgment_tween = create_tween()
	# Small upward pop, hold, then fade both labels together.
	judgment_tween.tween_property(judgment, "position:y", 740.0, 0.08)
	judgment_tween.tween_interval(0.35)
	judgment_tween.tween_property(judgment, "modulate:a", 0.0, 0.25)
	judgment_tween.parallel().tween_property(combo_label, "modulate:a", 0.0, 0.25)


# Big centered text: countdown, waiting, match results.
# big = huge digits for the countdown. duration 0 = stay until replaced.
func show_message(title: String, subtitle: String = "", big: bool = false, duration: float = 0.0) -> void:
	%MessageTitle.text = title
	%MessageTitle.add_theme_font_size_override("font_size", 96 if big else 48)
	%MessageSub.text = subtitle
	%MessageSub.visible = subtitle != ""
	%Message.show()
	if message_tween:
		message_tween.kill()
	if duration > 0.0:
		message_tween = create_tween()
		message_tween.tween_interval(duration)
		message_tween.tween_callback(%Message.hide)


func hide_message() -> void:
	%Message.hide()


# --- Helpers ----------------------------------------------------------------

func _fill_hearts(box: HBoxContainer) -> void:
	for i in 3:
		var heart := TextureRect.new()
		heart.texture = HEART_TEXTURE
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.custom_minimum_size = Vector2(21, 18) # 7×6 pixels at ×3.
		heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(heart)


func _show_hearts(box: HBoxContainer, lives: int) -> void:
	for i in box.get_child_count():
		var heart: CanvasItem = box.get_child(i)
		heart.modulate = FULL_HEART if i < lives else EMPTY_HEART
