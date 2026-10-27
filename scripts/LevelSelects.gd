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
	meals[1].pressed.connect(_on_lunch_pressed) # Index 1 is Lunch.


func _on_breakfast_pressed() -> void:
	# Open the playable Breakfast scene.
	get_tree().change_scene_to_file("res://scenes/levels/level_01.tscn")

func _on_lunch_pressed() -> void:
	if GameState.unlocked_level < 2:
		return # Only allow Lunch after it has been unlocked.

	# Open the Lunch scene using its exact file path.
	get_tree().change_scene_to_file("res://scenes/levels/level_02.tscn")
