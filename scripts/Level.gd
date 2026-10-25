extends Node2D

const BPM: float = 90.0 # Breakfast's exact tempo.
var song_time: float = 0.0 # Seconds heard by the player.
var last_beat: int = -1 # Remember which beat we already printed.
var test_judged: bool = false # Judge this apple only once.
var breakfast_notes: Array[Dictionary] = [] # Our playable note list.

@onready var music: AudioStreamPlayer = $Music # Find our Music child.
@onready var output_latency: float = AudioServer.get_output_latency()
@onready var test_food: Node2D = $Food # Find our test apple.
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
	# Start falling at 1 second; reach the catch line at 4 seconds.
	var progress: float = (song_time - 1.0) / 3.0
	# Keep the apple hidden after it has been judged.
	test_food.visible = not test_judged and progress >= 0.0 and progress <= 1.2
	# Keep the apple in the middle lane.
	test_food.position.x = get_viewport_rect().size.x / 2.0
	# Move from above the screen to our temporary catch line.
	test_food.position.y = lerpf(-96.0, 960.0, progress)
	judge_test_food() # Check this apple against the audio clock.
	var beat: int = floori(song_time * BPM / 60.0)
	

	if beat > last_beat:
		last_beat = beat # Print only when we reach a new beat.
		print("Beat ", beat + 1) # Show human-friendly numbering from 1.


func judge_test_food() -> void:
	if test_judged or song_time < 4.0:
		return # Wait for arrival; skip apples already judged.

	var lateness: float = song_time - 4.0
	if lateness > 0.16:
		judgment_label.text = "MISS" # Show a missed apple.
	elif catcher.get("lane") == 1:
		# Read the catcher's lane: 1 means the middle.
		if lateness <= 0.06:
			judgment_label.text = "PERFECT" # Show an on-time catch.
		else:
			judgment_label.text = "GOOD" # Show a slightly late catch.
	else:
		return # There's still time to move into the middle.

	test_judged = true # Prevent repeated catches or misses.
	test_food.hide() # Remove the judged apple immediately.

func pitch_to_lane(midi: int) -> int:
	if midi <= 76:
		return 0 # Lower pitches go left.
	elif midi <= 81:
		return 1 # Middle pitches go in the middle.
	return 2 # Higher pitches go right.
