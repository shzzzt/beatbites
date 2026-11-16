class_name GameHUD
extends Control
# Gameplay HUD (mockups 05 and 08). Level.gd creates it and calls these
# functions; the HUD never changes game rules, it only shows numbers.
#   Solo:          level name, score, hearts, goal bar
#   VS CPU/Online: YOU vs RIVAL panel + tug bar, power-up status chip, and the
#                  power-up animations (throws, tossed hazards, ink, shield)

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
const GOLD := Color("#9A5B0C")

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


# --- Power-up animations -------------------------------------------------------
# All positions are in screen pixels (the HUD covers the whole 720×1280 screen,
# the same coordinates the level uses for food and the catcher).

const INK_COLOR := Color("#4A3A7A")
const INK_SPOT := Color("#7A66B8")
const INK_TRAIL := Color(0.36, 0.27, 0.58, 0.8)
const INK_DEBRIS: Array[Color] = [Color("#4A3A7A"), Color("#7A66B8"), Color("#5B4494")]
const SHIELD_DEBRIS: Array[Color] = [Color("#2667B0"), Color("#BFE2FF"), Color("#FFFFFF")]
const GOLD_DEBRIS: Array[Color] = [Color("#F2B230"), Color("#FFE27A"), Color("#FFFFFF")]
const PIXEL: float = 12.0 # Ink blobs are drawn as 12×12 squares (pixel style).


# We caught a THROW or INK power: the projectile arcs from our axolotl to the
# rival's side of the score panel. blocked = the rival had a shield up.
func play_throw(from: Vector2, kind: String, blocked: bool) -> void:
	_float_text(from + Vector2(0, -130), "INK!" if kind == "ink" else "THROW!", PINK)
	var target: Vector2 = _center_of(%Rival)
	var projectile: Node2D = _make_ink_ball() if kind == "ink" else _make_rotten_sprite()
	_launch(projectile, from, func() -> Vector2: return target, Vector2(110, -320), 1.5,
		func() -> void:
			if blocked:
				_impact(target, "BLOCKED!", BLUE, SHIELD_DEBRIS)
				return
			_impact(target, "SPLAT!", ROTTEN, INK_DEBRIS if kind == "ink" else DEBRIS_COLORS)
			_shake(%VersusPanel)
			_flash(%VersusPanel)
	)


# The rival is about to throw at us: banner, and their side of the panel winds up.
func play_warning(kind: String) -> void:
	show_incoming("INK INCOMING!" if kind == "ink" else "INCOMING!")
	var panel: Control = %VersusPanel
	panel.pivot_offset = panel.size / 2.0
	var wind_up := create_tween()
	wind_up.tween_property(panel, "scale", Vector2(1.08, 1.08), 0.1)
	wind_up.tween_property(panel, "scale", Vector2.ONE, 0.15)


# One rotten food tossed onto our field from the rival's side, on a random
# wobbly curve with a random spin. delay staggers several tosses.
# target = where it lands; on_land runs at that moment.
func toss_rotten(delay: float, target: Vector2, on_land: Callable) -> void:
	if delay > 0.0:
		# false = this timer stops while the game is paused.
		await get_tree().create_timer(delay, false).timeout
	var bend := Vector2(randf_range(-280.0, 280.0), randf_range(-140.0, 40.0))
	var spins: float = randf_range(1.0, 2.5) * (1.0 if randf() < 0.5 else -1.0)
	_launch(_make_rotten_sprite(), _center_of(%Rival), func() -> Vector2: return target,
		bend, spins,
		func() -> void:
			on_land.call()
			_impact(target, "", ROTTEN, DEBRIS_COLORS)
	)


# The rival's INK hit us: an ink ball flies in and splats purple pixel blobs
# over part of the field for `duration` seconds (food passes under them).
func play_ink_hit(duration: float) -> void:
	var land := Vector2(360, 620)
	_launch(_make_ink_ball(), _center_of(%Rival), func() -> Vector2: return land,
		Vector2(-160, -60), 1.0,
		func() -> void:
			_impact(land, "INKED!", INK_COLOR, INK_DEBRIS)
			_spawn_ink(duration)
	)


# Our shield blocked the rival's throw.
func play_blocked(at: Vector2) -> void:
	_launch(_make_rotten_sprite(), _center_of(%Rival), func() -> Vector2: return at,
		Vector2(140, -80), 1.5,
		func() -> void: _impact(at, "BLOCKED!", BLUE, SHIELD_DEBRIS)
	)


# We caught a SHIELD or x2 power: name pops up above the axolotl with sparkles.
func show_power(at: Vector2, text: String, kind: String) -> void:
	var debris: Array[Color] = SHIELD_DEBRIS if kind == "shield" else GOLD_DEBRIS
	_impact(at + Vector2(0, -40), "", BLUE, debris)
	_float_text(at + Vector2(0, -130), text, BLUE if kind == "shield" else GOLD)


# The rival used a SHIELD or x2 on themselves: short note by their panel.
func show_rival_power(text: String) -> void:
	_float_text(_center_of(%Rival) + Vector2(-60, 140), text, MUTED)


# Our active powers under the score panel, e.g. "SHIELD  x2 4s".
func set_status(shield: bool, double_left: float) -> void:
	var parts: PackedStringArray = []
	if shield:
		parts.append("SHIELD")
	if double_left > 0.0:
		parts.append("x2 %ds" % ceili(double_left))
	%Status.visible = not parts.is_empty()
	%StatusText.text = "  ".join(parts)


# Flies a projectile along a curve, spinning and leaving a trail.
# bend moves the curve's middle point (negative y = higher arc).
func _launch(projectile: Node2D, from: Vector2, get_target: Callable, bend: Vector2,
		spins: float, on_land: Callable) -> void:
	projectile.position = from
	add_child(projectile)
	var trail_color: Color = projectile.get_meta("trail", PUFF_COLOR)
	var trail: Dictionary = {"last": 0.0} # A Dictionary so the lambda can change it.
	var fly := func(t: float) -> void:
		var end: Vector2 = get_target.call()
		var middle: Vector2 = (from + end) / 2.0 + bend
		# Quadratic Bezier curve: start → middle → end.
		projectile.position = from.lerp(middle, t).lerp(middle.lerp(end, t), t).round()
		projectile.rotation = t * TAU * spins
		if t - trail["last"] >= 0.07:
			trail["last"] = t
			_puff(projectile.position, trail_color)
	var tween := create_tween()
	tween.tween_method(fly, 0.0, 1.0, FLIGHT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		projectile.queue_free()
		on_land.call()
	)


func _make_rotten_sprite() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = FallingFood.BAD_TEXTURES.pick_random()
	sprite.scale = Vector2(6, 6)
	return sprite


# A purple pixel ball (drawn with squares when Godot asks it to draw).
func _make_ink_ball() -> Node2D:
	var ball := Node2D.new()
	ball.set_meta("trail", INK_TRAIL)
	ball.draw.connect(func() -> void:
		for y in range(-4, 4):
			for x in range(-4, 4):
				if Vector2(x + 0.5, y + 0.5).length() <= 4.0:
					var spot: bool = x == -2 and y == -2 # One light pixel = shine.
					ball.draw_rect(Rect2(x * PIXEL, y * PIXEL, PIXEL, PIXEL),
						INK_SPOT if spot else INK_COLOR)
	)
	return ball


# Big ink blobs on the field; they pop in, stay, then fade away.
func _spawn_ink(duration: float) -> void:
	var ink := Control.new()
	ink.size = size
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Each blob: center x, center y, radius. Big blobs plus small drips.
	var blobs: Array[Vector3] = []
	for i in 3:
		blobs.append(Vector3(randf_range(140, 580), randf_range(400, 840), randf_range(96, 132)))
	for i in 6:
		var parent: Vector3 = blobs[i % 3]
		var offset: Vector2 = Vector2.RIGHT.rotated(randf() * TAU) * (parent.z + 30.0)
		blobs.append(Vector3(parent.x + offset.x, parent.y + offset.y, randf_range(18, 36)))
	ink.draw.connect(func() -> void:
		for blob in blobs:
			var center := (Vector2(blob.x, blob.y) / PIXEL).floor() * PIXEL # Snap to grid.
			var cells: int = ceili(blob.z / PIXEL)
			for gy in range(-cells, cells + 1):
				for gx in range(-cells, cells + 1):
					var cell := Vector2(gx, gy) * PIXEL
					# Wobbly edge: the radius changes a little with the angle.
					var edge: float = blob.z * (0.85 + 0.15 * sin(cell.angle() * 5.0 + blob.z))
					if cell.length() > edge:
						continue
					var shine: bool = (cell + Vector2(blob.z, blob.z) * 0.35).length() < blob.z * 0.22
					ink.draw_rect(Rect2(center + cell, Vector2(PIXEL, PIXEL)), INK_SPOT if shine else INK_COLOR)
	)
	add_child(ink)
	move_child(ink, 0) # Under the score panels and pop-up text.
	ink.pivot_offset = Vector2(360, 620)
	ink.scale = Vector2(0.4, 0.4)
	var tween := create_tween()
	tween.tween_property(ink, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(duration)
	tween.tween_property(ink, "modulate:a", 0.0, 0.6)
	tween.tween_callback(ink.queue_free)


# Splat at a spot: flying pixel debris (+ floating text if any).
func _impact(spot: Vector2, text: String, text_color: Color, debris: Array[Color]) -> void:
	for i in 12:
		var bit := ColorRect.new()
		bit.color = debris[i % debris.size()]
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
	if text != "":
		_float_text(spot + Vector2(0, -70), text, text_color)


# One square of the trail; fades out by itself.
func _puff(spot: Vector2, color: Color) -> void:
	var puff := ColorRect.new()
	puff.color = color
	puff.size = Vector2(18, 18)
	puff.mouse_filter = Control.MOUSE_FILTER_IGNORE
	puff.position = spot - puff.size / 2.0
	add_child(puff)
	move_child(puff, 0) # Behind the flying food.
	var tween := create_tween()
	tween.tween_property(puff, "modulate:a", 0.0, 0.3)
	tween.tween_callback(puff.queue_free)


# Text that floats up and fades (THROW!, SPLAT!, BLOCKED!...).
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

func show_incoming(text: String = "INCOMING!") -> void:
	%IncomingText.text = text
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
