extends Node2D
# Load the scene we'll use to create food.
const FOOD_SCENE = preload("res://scenes/actors/food.tscn")
const BPM: float = 90.0 # Breakfast's exact tempo.

var score: int = 0 # Total points earned.
var combo: int = 0 # Consecutive successful catches.
var caught_count: int = 0 # Good foods caught toward the level goal.
var song_time: float = 0.0 # Seconds heard by the player.
var last_beat: int = -1 # Remember which beat we already printed.	
var breakfast_notes: Array[Dictionary] = [] # Our playable note list.
var active_food: Array[FallingFood] = [] # Remember our spawned foods.

@onready var music: AudioStreamPlayer = $Music # Find our Music child.
@onready var output_latency: float = AudioServer.get_output_latency()
@onready var catcher: Node2D = $Catcher # Find the catcher in this level.
@onready var judgment_label: Label = $HUD/Judgment # Find the HUD text.

func _ready() -> void:
	# Read the chart file as text.
	var text: String = FileAccess.get_file_as_string(
		"res://assets/audio/music_breakfast.json"
	)
	# Convert JSON text into data we can access by name.
	var chart: Dictionary = JSON.parse_string(text)
		# Build our playable list before spawning any food.
		
	for note in chart["lead_notes"]:
		var beat: float = float(note["beat"])
		# Breakfast accepts notes starting on whole beats.
		if is_equal_approx(beat, roundf(beat)):
			breakfast_notes.append({
				"time": beat * 60.0 / BPM, # Arrival time in seconds.
				"midi": int(note["midi"]), # Original pitch.
				"lane": pitch_to_lane(int(note["midi"])) # Catch lane.
			})
			
	# Preview the chart after its opening three seconds.
	for note in breakfast_notes:
		if float(note["time"]) < 3.0:
			continue # Skip opening notes until we add the countdown.
		var food: FallingFood = FOOD_SCENE.instantiate() as FallingFood
		food.arrival_time = float(note["time"]) # Each gets its own timing.
		food.lane = int(note["lane"]) # Each gets its own lane.
		food.hide() # Stay hidden until the fall begins.
		food.judgment_made.connect(_on_food_judgment)
		add_child(food) # Put this instance into the level.
		active_food.append(food) # Remember it for updates.
			
	

	print("Breakfast playable notes: ", breakfast_notes.size())
	print("First playable note: ", breakfast_notes[0])
	# Check that we loaded the expected song and notes.
	print("Chart BPM: ", chart["bpm"])
	print("Melody notes: ", chart["lead_notes"].size())
	print("First note: ", chart["lead_notes"][0])
	
func _process(_delta: float) -> void:
	if not music.playing:
		return # Stop checking when the music isn't playing.

	# Read playback time and compensate for audio buffering.
	var clock: float = music.get_playback_position()
	clock += AudioServer.get_time_since_last_mix()
	clock -= output_latency

	if clock < 0.0:
		return # The first sound hasn't reached the speakers yet.

	song_time = maxf(song_time, clock) # Prevent small backward jumps.
	
	# Ask the food to position itself using the music clock.
		# Give every food the same audio clock and player input.
	for food in active_food:
		food.update_from_song(song_time, get_viewport_rect().size.x)
		food.judge_catch(song_time, int(catcher.get("lane")))
	var beat: int = floori(song_time * BPM / 60.0)
	

	if beat > last_beat:
		last_beat = beat # Print only when we reach a new beat.
		print("Beat ", beat + 1) # Show human-friendly numbering from 1.

func _on_food_judgment(result: String) -> void:
	if result == "MISS":
		combo = 0 # A missed good food breaks the streak.
	else:
		combo += 1 # PERFECT and GOOD both continue the streak.
		caught_count += 1 # Both count toward the catch goal.
		if result == "PERFECT":
			score += 100
		else:
			score += 50 # GOOD earns fewer points.

	# Update the existing label with feedback and totals.
	judgment_label.text = "%s\nScore: %d\nCombo: %d\nCaught: %d" % [
		result, score, combo, caught_count
	]
	
func pitch_to_lane(midi: int) -> int:
	if midi <= 76:
		return 0 # Lower pitches go left.
	elif midi <= 81:
		return 1 # Middle pitches go in the middle.
	return 2 # Higher pitches go right.
