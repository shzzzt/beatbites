extends Control

@onready var heading: Label = $Content/Heading
@onready var details: Label = $Content/Details
@onready var retry_button: Button = $Content/Retry # Find the Retry button.
@onready var meals_button: Button = $Content/Meals # Find the Meals button.
@onready var next_button: Button = $Content/Next # Opens the following meal.

func _ready() -> void:
	var result: Dictionary = GameState.last_result # Read the last attempt.
	# Enable Retry only when we know which level was played.
	retry_button.disabled = result.is_empty()
	retry_button.pressed.connect(_on_retry_pressed)
	
	meals_button.pressed.connect(_on_meals_pressed) # Listen for a press.
	
	if result.is_empty():
		details.text = "Play a level to see your results."
		return # Allows this scene to be previewed safely with F6.

	heading.text = "TRY AGAIN"
	if result["won"]:
		heading.text = "LEVEL CLEARED!"

	# Fill the details label with the stored numbers.
	details.text = "Score: %d\nCaught: %d / %d" % [
		result["score"], result["caught"], result["goal"]
	]
	# Add the attempt's judgment totals and longest streak.
	var counts: Dictionary = result["judgments"]
	details.text += "\nPERFECT: %d\nGOOD: %d\nMISS: %d\nMax combo: %d" % [
		counts["PERFECT"], counts["GOOD"], counts["MISS"], result["max_combo"]
	]
	
	details.text += "\nLives left: %d" % result["lives"]

	if result.get("mode", "solo") == "online":
		# Online matches end by leaving the connection and going back to the lobby.
		retry_button.hide()
		meals_button.text = "BACK TO LOBBY"
		# Online has no stars; show the rival's final numbers instead.
		details.text += "\nRival score: %d\nRival lives: %d" % [
			result["opp_score"], result["opp_lives"]
		]
		heading.text = result["online_outcome"] # YOU WIN!, YOU LOSE or DRAW.
		return

	details.text += "\nStars: %d / 3" % result["stars"]

	# NEXT only when there is a next meal and it's already unlocked.
	var level: int = int(result.get("level_number", 0))
	if level >= 1 and level < 5 and GameState.unlocked_level > level:
		next_button.show()
		next_button.pressed.connect(_on_next_pressed)

	if result.get("mode", "solo") == "cpu":
		heading.text = result["cpu_outcome"] # Win, loss, or draw.
	else:
		heading.text = "TRY AGAIN"
		if result["won"]:
			heading.text = "LEVEL CLEARED!"
			
func _on_retry_pressed() -> void:
	# Read the scene path saved by the previous attempt.
	var level_path: String = str(GameState.last_result["level_path"])
	retry_button.disabled = true # Prevent repeated presses.
	get_tree().change_scene_to_file(level_path) # Start a fresh level.

func _on_next_pressed() -> void:
	next_button.disabled = true # Prevent repeated presses.
	var next_level: int = int(GameState.last_result["level_number"]) + 1
	get_tree().change_scene_to_file("res://scenes/levels/level_%02d.tscn" % next_level)

func _on_meals_pressed() -> void:
	meals_button.disabled = true # Prevent repeated presses.
	if GameState.last_result.get("mode", "solo") == "online":
		Net.leave_game() # Close the connection so the next match starts clean.
		get_tree().change_scene_to_file("res://scenes/ui/Lobby.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/ui/LevelSelect.tscn")
