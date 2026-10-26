extends Control

@onready var heading: Label = $Content/Heading
@onready var details: Label = $Content/Details
@onready var retry_button: Button = $Content/Retry # Find the Retry button.


func _ready() -> void:
	var result: Dictionary = GameState.last_result # Read the last attempt.
	# Enable Retry only when we know which level was played.
	retry_button.disabled = result.is_empty()
	retry_button.pressed.connect(_on_retry_pressed)
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
func _on_retry_pressed() -> void:
	# Read the scene path saved by the previous attempt.
	var level_path: String = str(GameState.last_result["level_path"])
	retry_button.disabled = true # Prevent repeated presses.
	get_tree().change_scene_to_file(level_path) # Start a fresh level.
