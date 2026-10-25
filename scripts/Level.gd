extends Node2D

const BPM: float = 90.0 # Breakfast's exact tempo.
var song_time: float = 0.0 # Seconds heard by the player.
var last_beat: int = -1 # Remember which beat we already printed.

@onready var music: AudioStreamPlayer = $Music # Find our Music child.
@onready var output_latency: float = AudioServer.get_output_latency()
@onready var test_food: Node2D = $Food # Find our test apple.

func _ready() -> void:
	# Read the chart file as text.
	var text: String = FileAccess.get_file_as_string(
		"res://assets/audio/music_breakfast.json"
	)
	# Convert JSON text into data we can access by name.
	var chart: Dictionary = JSON.parse_string(text)
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
	test_food.visible = progress >= 0.0 and progress <= 1.2
	# Keep the apple in the middle lane.
	test_food.position.x = get_viewport_rect().size.x / 2.0
	# Move from above the screen to our temporary catch line.
	test_food.position.y = lerpf(-96.0, 960.0, progress)
	var beat: int = floori(song_time * BPM / 60.0)

	if beat > last_beat:
		last_beat = beat # Print only when we reach a new beat.
		print("Beat ", beat + 1) # Show human-friendly numbering from 1.
