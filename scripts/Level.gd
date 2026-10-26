extends Node2D
# Load the scene we'll use to create food.
const FOOD_SCENE = preload("res://scenes/actors/food.tscn")
const BPM: float = 90.0 # Breakfast's exact tempo.
const TARGET_CATCHES: int = 40 # Successful catches needed to clear.

var score: int = 0 # Total points earned.
var combo: int = 0 # Consecutive successful catches.
var caught_count: int = 0 # Good foods caught toward the level goal.
var song_time: float = -3.0 # Start three seconds before the song.
var countdown_start_ms: int = 0 # When the countdown began.
var music_started: bool = false # Distinguish countdown from song ending.
var last_beat: int = -1 # Remember which beat we already printed.	
var breakfast_notes: Array[Dictionary] = [] # Our playable note list.
var active_food: Array[FallingFood] = [] # Remember our spawned foods.
var finished: bool = false # Prevent gameplay updates after the ending.
var judgment_counts: Dictionary = {"PERFECT": 0, "GOOD": 0, "MISS": 0}
var max_combo: int = 0 # Longest streak during this attempt.

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
		var food: FallingFood = FOOD_SCENE.instantiate() as FallingFood
		food.arrival_time = float(note["time"]) # Each gets its own timing.
		food.lane = int(note["lane"]) # Each gets its own lane.
		food.hide() # Stay hidden until the fall begins.
		food.judgment_made.connect(_on_food_judgment)
		add_child(food) # Put this instance into the level.
		active_food.append(food) # Remember it for updates.
			
	# End the attempt when the non-looping song finishes.
	music.finished.connect(_on_song_finished)
	judgment_label.text = "Goal: catch %d bites!" % TARGET_CATCHES
	
	await start_countdown() # Wait for the countdown to start the music.
	
	print("Breakfast playable notes: ", breakfast_notes.size())
	print("First playable note: ", breakfast_notes[0])
	# Check that we loaded the expected song and notes.
	print("Chart BPM: ", chart["bpm"])
	print("Melody notes: ", chart["lead_notes"].size())
	print("First note: ", chart["lead_notes"][0])
	
func _process(_delta: float) -> void:
	if finished:
		return # Stop updating after the attempt ends.

	song_time = read_song_time() # Works during countdown and playback.
	
	# Give every food the same audio clock and player input.
	for food in active_food:
		food.update_from_song(song_time, get_viewport_rect().size.x)
		food.judge_catch(song_time, int(catcher.get("lane")))
	var beat: int = floori(song_time * BPM / 60.0)
	

	if beat > last_beat:
		last_beat = beat # Print only when we reach a new beat.
		print("Beat ", beat + 1) # Show human-friendly numbering from 1.

func _on_food_judgment(result: String) -> void:
	judgment_counts[result] += 1 # Count this food's judgment once.
	if result == "MISS":
		combo = 0 # A missed good food breaks the streak.
	else:
		combo += 1 # PERFECT and GOOD both continue the streak.
		max_combo = maxi(max_combo, combo) # Keep the highest streak.
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

func _on_song_finished() -> void:
	if finished:
		return # End this attempt only once.

	finished = true

	if caught_count >= TARGET_CATCHES:
		GameState.complete_level(1) # This scene is Breakfast, level 1.

	# Keep the results after the gameplay scene is removed.
	GameState.last_result = {
		"won": caught_count >= TARGET_CATCHES,
		"score": score,
		"caught": caught_count,
		"goal": TARGET_CATCHES,
		"judgments": judgment_counts.duplicate(), # Copy the final counts.
		"max_combo": max_combo,
		"level_path": scene_file_path # Remember this level for Retry.
	}
	# Open our separate Result screen.
	get_tree().change_scene_to_file("res://scenes/ui/Result.tscn")
	
func start_countdown() -> void:
	countdown_start_ms = Time.get_ticks_msec() # Read the elapsed-time clock.
	# Count backward: 3, 2, 1.
	for number in range(3, 0, -1):
		judgment_label.text = str(number)
		# Wait one second; this timer will respect a future pause.
		await get_tree().create_timer(1.0, false).timeout

	judgment_label.text = "Goal: catch %d bites!" % TARGET_CATCHES
	music_started = true # The countdown has finished.
	music.play() # Begin playback from the start.
	
func read_song_time() -> float:
	if music.playing:
		# Use the audio clock once playback starts.
		var clock: float = music.get_playback_position()
		clock += AudioServer.get_time_since_last_mix()
		clock -= output_latency
		return maxf(song_time, clock) # Prevent backward jumps.

	if music_started:
		return song_time # Hold the clock when playback ends.

	# Before music starts, advance from -3 toward zero.
	var elapsed: float = (Time.get_ticks_msec() - countdown_start_ms) / 1000.0
	return minf(-0.001, elapsed - 3.0) # Let audio determine the zero crossing.
