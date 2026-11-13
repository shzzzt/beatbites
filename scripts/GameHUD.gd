class_name GameHUD
extends Control
# Gameplay HUD (mockups 05 and 08). Level.gd creates it and calls these
# functions; the HUD never changes game rules, it only shows numbers.
#   Solo:          level name, score, hearts, goal bar
#   VS CPU/Online: YOU vs RIVAL panel + tug bar (+ throw meter online)

signal move_requested(direction: int) # -1 = left zone, +1 = right zone.

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

var throw_boxes: Array[Panel] = []
var judgment_tween: Tween
var message_tween: Tween
var incoming_tween: Tween


func _ready() -> void:
	%LeftZone.pressed.connect(func() -> void: move_requested.emit(-1))
	%RightZone.pressed.connect(func() -> void: move_requested.emit(1))
	_fill_hearts(%YouHearts)
	_fill_hearts(%RivalHearts)
	# Ten boxes for the throw meter, filled in by set_throw().
	for i in 10:
		var box := Panel.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.theme_type_variation = &"ThrowOff"
		%ThrowBoxes.add_child(box)
		throw_boxes.append(box)


# mode: "solo", "cpu" or "online".
func setup(mode: String, level: int, meal: String) -> void:
	%LevelName.text = "LV %d · %s" % [level, meal.to_upper()]
	%SoloTop.visible = mode == "solo"
	%VersusTop.visible = mode != "solo"
	%ThrowPanel.visible = mode == "online"
	%RivalName.text = "CPU" if mode == "cpu" else "RIVAL"


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


# filled = catches toward the next throw (0-9).
func set_throw(filled: int, just_thrown: bool) -> void:
	for i in throw_boxes.size():
		var on: bool = just_thrown or i < filled
		throw_boxes[i].theme_type_variation = &"ThrowOn" if on else &"ThrowOff"
	%ThrowCount.text = "THROWN!" if just_thrown else "%d / 10 combo" % filled


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
