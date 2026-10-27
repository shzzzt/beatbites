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
		
		if meals[index].disabled:
			meals[index].text += "\nLOCKED" # Explain the disabled button.
		else:
			# Read this meal's best rating, defaulting to zero.
			var stars: int = int(GameState.best_stars.get(level, 0))
			meals[index].text += "\nBest stars: %d / 3" % stars

	# Connect Breakfast now; we'll connect other meals as we build them.
	meals[0].pressed.connect(_on_breakfast_pressed)
	meals[1].pressed.connect(_on_lunch_pressed) # Index 1 is Lunch.
	meals[2].pressed.connect(_on_snack_pressed) # Index 2 is Snack.
	meals[3].pressed.connect(_on_dinner_pressed) # Index 3 is Dinner.
	meals[4].pressed.connect(_on_dessert_pressed) # Index 4 is Dessert.
	
func _on_breakfast_pressed() -> void:
	# Open the playable Breakfast scene.
	get_tree().change_scene_to_file("res://scenes/levels/level_01.tscn")

func _on_lunch_pressed() -> void:
	if GameState.unlocked_level < 2:
		return # Only allow Lunch after it has been unlocked.

	# Open the Lunch scene using its exact file path.
	get_tree().change_scene_to_file("res://scenes/levels/level_02.tscn")

func _on_snack_pressed() -> void:
	if GameState.unlocked_level < 3:
		return # Snack requires clearing Lunch first.

	# Open Snack using the exact saved scene path.
	get_tree().change_scene_to_file("res://scenes/levels/level_03.tscn")	

func _on_dinner_pressed() -> void:
	if GameState.unlocked_level < 4:
		return # Dinner requires clearing Snack first.

	get_tree().change_scene_to_file("res://scenes/levels/level_04.tscn")


func _on_dessert_pressed() -> void:
	if GameState.unlocked_level < 5:
		return # Dessert requires clearing Dinner first.

	get_tree().change_scene_to_file("res://scenes/levels/level_05.tscn")
