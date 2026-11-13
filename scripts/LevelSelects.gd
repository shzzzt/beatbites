extends Control
# Level Select: one MealCard per meal, built from GameState.MEALS.

const CARD_SCENE = preload("res://scenes/ui/MealCard.tscn")


func _ready() -> void:
	%Back.pressed.connect(_on_back_pressed)
	%StarTotal.text = "%d/15" % GameState.total_stars()

	if GameState.mode == "cpu":
		%HintText.text = "VS CPU · beat the rival on any unlocked meal"
	else:
		%HintText.text = "Clear a meal to unlock the next one"

	for i in GameState.MEALS.size():
		var level: int = i + 1 # Array index 0 means level 1.
		var card: MealCard = CARD_SCENE.instantiate()
		%Cards.add_child(card) # Add first, so the card's @onready nodes exist.
		var locked: bool = level > GameState.unlocked_level
		var stars: int = int(GameState.best_stars.get(level, 0))
		card.setup(level, GameState.MEALS[i], stars, locked)
		card.pressed.connect(_on_meal_pressed.bind(level))


func _on_meal_pressed(level: int) -> void:
	if level > GameState.unlocked_level:
		return # Locked meals can't be opened (R4), even if a press slips through.
	get_tree().change_scene_to_file("res://scenes/levels/level_%02d.tscn" % level)


func _on_back_pressed() -> void:
	# Return to the offline mode picker.
	get_tree().change_scene_to_file("res://scenes/ui/OfflineSelect.tscn")
