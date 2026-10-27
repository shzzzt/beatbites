extends Node2D

@export var level_number: int = 1 # Breakfast = 1, Lunch = 2, etc.
@export_file("*.json") var chart_path: String = \
	"res://assets/audio/music_breakfast.json" # Chart used by this level.
@export var low_pitch_max: int = 76 # Highest pitch sent left.
@export var middle_pitch_max: int = 81 # Highest pitch sent to the middle.
@export_range(1, 2, 1) var notes_per_beat: int = 1 # 1 = whole; 2 = half beats.

# Load the scene we'll use to create food.
const FOOD_SCENE = preload("res://scenes/actors/food.tscn")
var bpm: float = 90.0 # Updated from the selected chart before building notes.
const TARGET_CATCHES: int = 40 # Successful catches needed to clear.
var cpu: CpuRival # Stays empty during Solo mode.
var cpu_note_index: int = 0 # Next food the CPU must evaluate.
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
var lives: int = 3 # Every new attempt starts with three lives.

@onready var music: AudioStreamPlayer = $Music # Find our Music child.
@onready var output_latency: float = AudioServer.get_output_latency()
@onready var catcher: Node2D = $Catcher # Find the catcher in this level.
@onready var judgment_label: Label = $HUD/Judgment # Find the HUD text.

func _ready() -> void:
	# Read the chart file as text.
	var text: String = FileAccess.get_file_as_string(chart_path)
	# Convert JSON text into data we can access by name.
	var chart: Dictionary = JSON.parse_string(text)
		# Build our playable list before spawning any food.
	bpm = float(chart["bpm"]) # Use this song's exact tempo.
	
	for note in chart["lead_notes"]:
		var beat: float = float(note["beat"])
		# Breakfast accepts notes starting on whole beats.
		# A half-beat becomes a whole number when multiplied by two.
		var grid_position: float = beat * notes_per_beat
		if is_equal_approx(grid_position, roundf(grid_position)):
			breakfast_notes.append({
				"time": beat * 60.0 / bpm, # Convert using this song's tempo.
				"midi": int(note["midi"]), # Original pitch.
				"lane": pitch_to_lane(int(note["midi"])) # Catch lane.
			})
	
	var food_index: int = 0 # Count foods as we create them.
	# Preview the chart after its opening three seconds.
	for note in breakfast_notes:
		var food: FallingFood = FOOD_SCENE.instantiate() as FallingFood
		# Snack onward: every tenth food is rotten.
		food.is_bad = level_number >= 3 and food_index % 10 == 9
		food_index += 1 # Advance to the next food number.
		food.arrival_time = float(note["time"]) # Each gets its own timing.
		food.lane = int(note["lane"]) # Each gets its own lane.
		food.hide() # Stay hidden until the fall begins.
		food.judgment_made.connect(_on_food_judgment)
		add_child(food) # Put this instance into the level.
		active_food.append(food) # Remember it for updates.
			
	# End the attempt when the non-looping song finishes.
	music.finished.connect(_on_song_finished)
	judgment_label.text = "Goal: catch %d bites!" % TARGET_CATCHES
	
	if GameState.mode == "cpu":
		cpu = CpuRival.new() # Create an independent rival.
		cpu.setup(level_number) # Set this meal's accuracy.
	
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
	update_cpu() # Evaluate notes whose arrival time has passed.	
	# Give every food the same audio clock and player input.
	for food in active_food:
		food.update_from_song(song_time, get_viewport_rect().size.x)
		food.judge_catch(song_time, int(catcher.get("lane")))
	var beat: int = floori(song_time * bpm / 60.0)
	

	if beat > last_beat:
		last_beat = beat # Print only when we reach a new beat.
		print("Beat ", beat + 1) # Show human-friendly numbering from 1.

func _on_food_judgment(result: String) -> void:
	if finished:
		return # Ignore judgments after the attempt ends.

	if result == "HIT_BAD":
		lives = maxi(0, lives - 1) # Lose exactly one life.
		judgment_label.text = "ROTTEN!\nLives: %d" % lives
		if lives == 0:
			end_attempt(false) # Lose immediately, regardless of score.
		return

	if result == "AVOIDED":
		judgment_label.text = "DODGED!\nLives: %d" % lives
		return # Avoiding rotten food isn't a MISS.
	
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

	# Show the current attempt's counters.
	judgment_label.text = "%s\nScore: %d\nCombo: %d\nCaught: %d\nLives: %d" % [
		result, score, combo, caught_count, lives
	]
	
func pitch_to_lane(midi: int) -> int:
	if midi <= low_pitch_max:
		return 0 # Lower pitches go left.
	elif midi <= middle_pitch_max:
		return 1 # Middle pitches go in the middle.
	return 2 # Everything higher goes right.

func _on_song_finished() -> void:
	# Clearing requires enough catches and at least one remaining life.
	end_attempt(caught_count >= TARGET_CATCHES and lives > 0)


func end_attempt(won: bool) -> void:
	if finished:
		return # End the attempt only once.

	finished = true # Block further gameplay results.
	music.stop() # Stop music when losing before the song ends.
	# A win earns one star per remaining life; a loss earns none.
	var stars: int = lives if won else 0
	
	if won:
		GameState.complete_level(level_number, stars) # Save this win's rating.

	# Preserve the final numbers before leaving gameplay.
	GameState.last_result = {
		"won": won,
		"stars": stars, # Send this attempt's rating to Result.
		"score": score,
		"caught": caught_count,
		"goal": TARGET_CATCHES,
		"lives": lives,
		"judgments": judgment_counts.duplicate(),
		"max_combo": max_combo,
		"level_path": scene_file_path
	}
	# Switch after the current food callbacks finish.
	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/result.tscn")
	
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


func update_cpu() -> void:
	if cpu == null:
		return # Solo mode has no rival.

	while cpu_note_index < active_food.size():
		var food: FallingFood = active_food[cpu_note_index]
		if food.arrival_time > song_time:
			break # This note hasn't arrived yet.

		cpu_note_index += 1 # Never evaluate the same note twice.
		if not food.is_bad:
			cpu.judge_good_note() # Simulate one good-food judgment.
			print("CPU score: ", cpu.score) # Temporary debug display.
