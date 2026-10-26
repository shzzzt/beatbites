extends Control

@onready var heading: Label = $Content/Heading
@onready var details: Label = $Content/Details


func _ready() -> void:
	var result: Dictionary = GameState.last_result # Read the last attempt.
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
