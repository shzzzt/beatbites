extends Control
# Credits screen. The cards are built from SECTIONS below, so to change a
# name or add a line, edit this list (no need to touch the scene).

const SOUND_ICON = preload("res://assets/art/icon_sound_on.png")
const DONUT_ICON = preload("res://assets/art/good_donut.png")
const STAR_ICON = preload("res://assets/art/ui_star.png")
const APPLE_ICON = preload("res://assets/art/good_apple.png")

# title, title color, icon (+ optional tint), then entries:
#   ["Big name", "small line under it"]  or  ["Track name", "Meal", "track"]
var SECTIONS: Array[Dictionary] = [
	{
		"title": "MADE BY", "color": Color("#D9468F"), "icon": DONUT_ICON,
		"entries": [
			["Shauntie Velasco", "Game design, code, rhythm charts and pixel art"],
		],
	},
	{
		"title": "MUSIC", "color": Color("#2667B0"), "icon": SOUND_ICON,
		"entries": [
			["ChatGPT (OpenAI)", "AI-generated soundtrack made for this game"],
			["A Table Under the Stars", "Menu", "track"],
			["Sunrise Bento", "Breakfast", "track"],
			["Lunchbox Letters", "Lunch", "track"],
			["Soda Pop Sidequest", "Snack", "track"],
			["Neon Noodle Rush", "Dinner", "track"],
			["Sugar Star Sprint", "Dessert", "track"],
			["Stardust Lullaby", "Endless bonus", "track"],
			["Bonus song & sound effects", "Composed in code with Claude Code (our own scripts)"],
		],
	},
	{
		"title": "PLAYTESTING", "color": Color("#3E7A12"), "icon": STAR_ICON,
		"tint": Color("#F2B230"), # ui_star.png is white, so tint it gold.
		"entries": [
			["Jan Eduard Sanchez", "Playtester"],
		],
	},
	{
		"title": "FONTS", "color": Color("#6B58A0"), "icon": null,
		"entries": [
			["Press Start 2P", "by CodeMan38 · SIL Open Font License 1.1"],
			["Pixelify Sans", "by Stefie Justprince · SIL Open Font License 1.1"],
		],
	},
	{
		"title": "TOOLS", "color": Color("#9A5B0C"), "icon": APPLE_ICON,
		"entries": [
			["Godot Engine 4.7", "Game engine · MIT License"],
			["Claude Code (Anthropic)", "Coding assistant used during development"],
		],
	},
]


func _ready() -> void:
	%Back.pressed.connect(_on_back_pressed)
	for section in SECTIONS:
		%Sections.add_child(make_section(section))


func _on_back_pressed() -> void:
	# Credits is opened from the mode select screen, so go back there.
	get_tree().change_scene_to_file("res://scenes/ui/ModeSelect.tscn")


# One white card: colored heading (with icon) and its entries.
func make_section(section: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	# PASS lets a finger drag on the card scroll the list (STOP would block it).
	card.mouse_filter = Control.MOUSE_FILTER_PASS

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 16)
	card.add_child(box)

	var heading := HBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_PASS
	heading.add_theme_constant_override("separation", 16)
	box.add_child(heading)
	if section["icon"] != null:
		var icon := TextureRect.new()
		icon.texture = section["icon"]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# Whole-number pixel scales: 16 px food ×3, 12 px icon ×4, 7 px star ×6.
		var pixels: int = section["icon"].get_width()
		var scale_factor: int = 3 if pixels >= 16 else (4 if pixels >= 12 else 6)
		icon.custom_minimum_size = Vector2(pixels, section["icon"].get_height()) * scale_factor
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.modulate = section.get("tint", Color.WHITE)
		heading.add_child(icon)
	var title := Label.new()
	title.theme_type_variation = &"SectionLabel"
	title.add_theme_color_override("font_color", section["color"])
	title.text = section["title"]
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(title)

	for entry: Array in section["entries"]:
		if entry.size() == 3:
			box.add_child(make_track_row(entry[0], entry[1]))
		else:
			box.add_child(make_person(entry[0], entry[1]))
	return card


# A name in bold with a smaller muted line underneath.
func make_person(big: String, small: String) -> VBoxContainer:
	var person := VBoxContainer.new()
	person.mouse_filter = Control.MOUSE_FILTER_PASS
	person.add_theme_constant_override("separation", 0)
	var name_label := Label.new()
	name_label.theme_type_variation = &"MealName"
	name_label.add_theme_font_size_override("font_size", 36)
	name_label.text = big
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	person.add_child(name_label)
	var role := Label.new()
	role.theme_type_variation = &"SmallMuted"
	role.text = small
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	person.add_child(role)
	return person


# "Sunrise Bento .......... Breakfast" in a pale tile.
func make_track_row(track: String, meal: String) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.theme_type_variation = &"TileLilac"
	tile.mouse_filter = Control.MOUSE_FILTER_PASS
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	tile.add_child(row)
	var track_label := Label.new()
	track_label.text = track
	track_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(track_label)
	var meal_label := Label.new()
	meal_label.theme_type_variation = &"SmallMuted"
	meal_label.text = meal
	row.add_child(meal_label)
	return tile
