extends Control

# Buttons are listed in meal order.
@onready var meals: Array[Button] = [
	$Content/Breakfast,
	$Content/Lunch,
	$Content/Snack,
	$Content/Dinner,
	$Content/Dessert
]


func _ready() -> void:
	for index in range(meals.size()):
		var level: int = index + 1 # Array index 0 means level 1.
		meals[index].disabled = level > GameState.unlocked_level

	# Connect Breakfast now; we'll connect other meals as we build them.
	meals[0].pressed.connect(_on_breakfast_pressed)


func _on_breakfast_pressed() -> void:
	# Open the playable Breakfast scene.
	get_tree().change_scene_to_file("res://scenes/levels/level_01.tscn")
