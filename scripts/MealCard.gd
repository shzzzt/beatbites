class_name MealCard
extends Button
# One row on the Level Select screen. LevelSelects.gd makes 5 of these
# and calls setup() on each one.

# ui_star.png is a white shape, so modulate gives it its exact color.
const FULL_STAR := Color("#F2B230")
const EMPTY_STAR := Color("#E3D4FF") # Pale lilac = not earned yet.
const TILE_STYLES: Array[StringName] = [&"NumBlue", &"NumPurple", &"NumPink"]

var level: int = 1

@onready var tile: PanelContainer = %Tile
@onready var number_label: Label = %Number
@onready var lock_icon: TextureRect = %Lock
@onready var name_label: Label = %MealName
@onready var info_label: Label = %Info
@onready var stars_box: HBoxContainer = %Stars
@onready var locked_tag: Label = %LockedTag
@onready var dashes: DashedLine = %Dashes


func setup(level_number: int, meal: Dictionary, stars: int, locked: bool) -> void:
	level = level_number
	info_label.text = "%d BPM · %s" % [meal["bpm"], meal["info"]]
	disabled = locked # A disabled button can't be pressed (R4).

	# Locked cards look different: lilac, dashed border, lock icon, "LOCKED".
	number_label.visible = not locked
	lock_icon.visible = locked
	stars_box.visible = not locked
	locked_tag.visible = locked
	dashes.visible = locked

	if locked:
		theme_type_variation = &"LockedCard"
		tile.theme_type_variation = &"NumLocked"
		name_label.text = "%d · %s" % [level_number, meal["name"]]
		name_label.add_theme_color_override("font_color", Color("#6B58A0"))
	else:
		theme_type_variation = &"WhiteButton"
		tile.theme_type_variation = TILE_STYLES[(level_number - 1) % TILE_STYLES.size()]
		number_label.text = str(level_number)
		name_label.text = str(meal["name"])
		for i in stars_box.get_child_count():
			var star: TextureRect = stars_box.get_child(i)
			star.modulate = FULL_STAR if i < stars else EMPTY_STAR
