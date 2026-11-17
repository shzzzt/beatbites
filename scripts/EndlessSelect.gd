extends Control
# Endless mode: pick a song. One card per song (the 5 meals + the bonus song),
# built in code. Each card shows the song, its tempo and your saved best.

const CARD_STYLES: Array[StringName] = [&"Button", &"BlueButton", &"PurpleButton"]
const ICONS: Array[Texture2D] = [
	preload("res://assets/art/good_apple.png"),
	preload("res://assets/art/good_fries.png"),
	preload("res://assets/art/good_candy.png"),
	preload("res://assets/art/good_bepsi.png"),
	preload("res://assets/art/good_donut.png"),
	preload("res://assets/art/good_icecream.png"),
]
const BONUS_COLOR := Color("#D9468F")


func _ready() -> void:
	%Back.pressed.connect(_on_back_pressed)
	for level in range(1, GameState.ENDLESS_LEVELS + 1):
		%List.add_child(make_card(level))


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/OfflineSelect.tscn")


func _play(level: int) -> void:
	GameState.mode = "endless"
	get_tree().change_scene_to_file("res://scenes/levels/level_%02d.tscn" % level)


func make_card(level: int) -> Button:
	var info: Dictionary = GameState.meal_info(level)
	var card := Button.new()
	card.theme_type_variation = CARD_STYLES[(level - 1) % CARD_STYLES.size()]
	card.custom_minimum_size = Vector2(0, 124)
	# PASS: a finger drag that starts on a card still scrolls the list.
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.pressed.connect(_play.bind(level))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)

	var icon := TextureRect.new()
	icon.texture = ICONS[level - 1]
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size = Vector2(80, 80) # 16 px × 5.
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", 4)
	row.add_child(text)

	var title := Label.new()
	title.theme_type_variation = &"CardTitle"
	title.add_theme_font_size_override("font_size", 24)
	title.text = str(info["name"]).to_upper()
	if level == 6:
		title.add_theme_color_override("font_color", BONUS_COLOR) # Bonus song stands out.
	text.add_child(title)

	var song := Label.new()
	song.theme_type_variation = &"CardBody"
	song.add_theme_font_size_override("font_size", 28)
	song.text = "%s · %d BPM" % [GameState.SONG_TITLES[level - 1], int(info["bpm"])]
	song.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(song)

	var best: Dictionary = GameState.endless_best.get(level, {})
	var record := Label.new()
	record.theme_type_variation = &"SmallMuted"
	if best.is_empty():
		record.text = "No run yet · new song!" if level == 6 else "No run yet"
	else:
		record.text = "BEST %05d · loop %d" % [int(best["score"]), int(best["loop"])]
	text.add_child(record)
	for label in [title, song, record]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card
