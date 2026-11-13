extends Control
# Result screen (mockup 07). Reads GameState.last_result, which Level.gd
# fills in when an attempt ends.

# ui_star.png is a white shape, so modulate gives it its exact color.
const FULL_STAR := Color("#F2B230")
const EMPTY_STAR := Color("#E3D4FF") # Pale lilac = not earned.

@onready var retry_button: Button = %Retry
@onready var meals_button: Button = %Meals # "MENU" / "BACK TO LOBBY".
@onready var next_button: Button = %Next # Opens the following meal.


func _ready() -> void:
	var result: Dictionary = GameState.last_result # Read the last attempt.
	# Enable Retry only when we know which level was played.
	retry_button.disabled = result.is_empty()
	retry_button.pressed.connect(_on_retry_pressed)
	meals_button.pressed.connect(_on_meals_pressed) # Listen for a press.

	if result.is_empty():
		%SubLine.text = "Play a level to see your results."
		return # Allows this scene to be previewed safely with F6.

	var mode: String = result.get("mode", "solo")
	var level: int = int(result.get("level_number", 1))
	%LevelLine.text = "LV %d · %s" % [level, GameState.meal_name(level).to_upper()]
	%SubLine.text = "Caught %d / %d · %d %s left" % [
		result["caught"], result["goal"], result["lives"],
		"life" if result["lives"] == 1 else "lives"
	]

	# Score card.
	var counts: Dictionary = result["judgments"]
	%ScoreValue.text = "%05d" % result["score"]
	%PerfectValue.text = str(counts["PERFECT"])
	%GoodValue.text = str(counts["GOOD"])
	%MissValue.text = str(counts["MISS"])
	%ComboValue.text = str(result["max_combo"])

	match mode:
		"online":
			# Online matches end by leaving the connection and going back to the lobby.
			%Heading.text = result["online_outcome"] # YOU WIN!, YOU LOSE, DRAW...
			%Stars.hide() # Stars are a Solo-only reward.
			show_rival("RIVAL", result["opp_score"], result["opp_lives"])
			retry_button.hide()
			meals_button.text = "BACK TO LOBBY"
		"cpu":
			%Heading.text = result["cpu_outcome"] # Win, loss, or draw.
			%Stars.hide()
			show_rival("CPU", result["cpu_score"], result["cpu_lives"])
			show_next_if_unlocked(level)
		_:
			%Heading.text = "LEVEL CLEARED!" if result["won"] else "TRY AGAIN"
			show_stars(int(result["stars"]))
			show_next_if_unlocked(level)
			# Green banner when this clear opened a new meal.
			if result.get("newly_unlocked", false) and level < 5:
				%UnlockedText.text = "%s unlocked!" % GameState.meal_name(level + 1)
				%Unlocked.show()


func show_rival(rival_name: String, rival_score: int, rival_lives: int) -> void:
	%RivalCaption.text = rival_name
	%RivalValue.text = "%05d · %d %s" % [
		rival_score, rival_lives, "life" if rival_lives == 1 else "lives"
	]
	%RivalRow.show()


# Earned stars pop in one after another; the rest stay faded.
func show_stars(earned: int) -> void:
	var tween: Tween = create_tween()
	for i in %Stars.get_child_count():
		var star: TextureRect = %Stars.get_child(i)
		if i < earned:
			star.modulate = FULL_STAR
			star.modulate.a = 0.0
			tween.tween_interval(0.15)
			tween.tween_property(star, "modulate:a", 1.0, 0.2)
		else:
			star.modulate = EMPTY_STAR


# NEXT only when there is a next meal and it's already unlocked.
func show_next_if_unlocked(level: int) -> void:
	if level >= 1 and level < 5 and GameState.unlocked_level > level:
		next_button.show()
		next_button.pressed.connect(_on_next_pressed)


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
