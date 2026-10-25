extends Node2D
# Load the scene we'll use to create food.
const FOOD_SCENE = preload("res://scenes/actors/food.tscn")
const BPM: float = 90.0 # Breakfast's exact tempo.

var song_time: float = 0.0 # Seconds heard by the player.
var last_beat: int = -1 # Remember which beat we already printed.	
var breakfast_notes: Array[Dictionary] = [] # Our playable note list.
var test_note: Dictionary = {} # Holds our chosen chart note.

@onready var music: AudioStreamPlayer = $Music # Find our Music child.
@onready var output_latency: float = AudioServer.get_output_latency()
var test_food: FallingFood # We'll create this node ourselves.
@onready var catcher: Node2D = $Catcher # Find the catcher in this level.
@onready var judgment_label: Label = $HUD/Judgment # Find the HUD text.

func _ready() -> void:
	# Read the chart file as text.
	var text: String = FileAccess.get_file_as_string(
		"res://assets/audio/music_breakfast.json"
	)
	# Convert JSON text into data we can access by name.
	var chart: Dictionary = JSON.parse_string(text)
	
	# Examine each melody note in the chart.
	for note in chart["lead_notes"]:
		var beat: float = float(note["beat"])
		# Keep whole beats, allowing tiny decimal rounding differences.
		if is_equal_approx(beat, roundf(beat)):
			breakfast_notes.append({
				"time": beat * 60.0 / BPM, # Scheduled arrival time.
				"midi": int(note["midi"]), # Original melody pitch.
				"lane": pitch_to_lane(int(note["midi"])) # Chosen lane.
			})
			
	test_food = FOOD_SCENE.instantiate() as FallingFood # Create a food.
	test_food.hide() # Keep it hidden until its falling time.
	add_child(test_food) # Add it to the running level.
	
	test_note = breakfast_notes[6] # Index 6 is the seventh note.
	test_food.arrival_time = float(test_note["time"]) # Copy its timing.
	test_food.lane = int(test_note["lane"]) # Copy its lane.
	
	# Run our HUD function whenever this food reports a judgment.
	test_food.judgment_made.connect(_on_food_judgment)
	
	print("Testing chart note: ", test_note)
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
	test_food.update_from_song(song_time, get_viewport_rect().size.x)
	# Give this food the current audio time and catcher lane.
	test_food.judge_catch(song_time, int(catcher.get("lane")))
	var beat: int = floori(song_time * BPM / 60.0)
	

	if beat > last_beat:
		last_beat = beat # Print only when we reach a new beat.
		print("Beat ", beat + 1) # Show human-friendly numbering from 1.

func _on_food_judgment(result: String) -> void:
	judgment_label.text = result # Display the food's reported result.
	
func pitch_to_lane(midi: int) -> int:
	if midi <= 76:
		return 0 # Lower pitches go left.
	elif midi <= 81:
		return 1 # Middle pitches go in the middle.
	return 2 # Higher pitches go right.
