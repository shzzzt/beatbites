extends Node2D

@export var level_number: int = 1 # Breakfast = 1, Lunch = 2, etc.
@export_file("*.json") var chart_path: String = \
	"res://assets/audio/music_breakfast.json" # Chart used by this level.
@export var low_pitch_max: int = 76 # Highest pitch sent left.
@export var middle_pitch_max: int = 81 # Highest pitch sent to the middle.
@export_range(1, 2, 1) var notes_per_beat: int = 1 # 1 = whole; 2 = half beats.

var opponent_label: Label
var last_sent_score: int = -1
var last_sent_lives: int = -1
var online_music_start_ms: float = -1.0 # Deadline on this phone's clock.
var waiting_for_online: bool = false # Freeze gameplay until both phones are ready.
var online_result_shown: bool = false # The online match has ended (result or disconnect).
var opp_last_score: int = 0 # Rival's latest numbers, kept in case they disconnect.
var opp_last_lives: int = 3
const MEAL_NAMES: Array[String] = ["Breakfast", "Lunch", "Snack", "Dinner", "Dessert"]
const RESULT_WAIT_EXTRA: float = 15.0 # Seconds to wait past the song's end for the rival.
const THROW_COMBO: int = 10 # Every 10-catch combo throws a rotten food at the rival.
const ATTACK_LEAD_TIME: float = 2.0 # Turn food rotten at least this long before it lands.
var throw_label: Label # Online throw meter.
var incoming_label: Label # Big "INCOMING!" warning.
var incoming_tween: Tween # Hides the warning after a short time.
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
var cpu_label: Label # Created only for VS CPU mode.
var cpu_outcome: String = "" # Final CPU match message.


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
		create_cpu_hud()
		
	if GameState.mode == "online":
		waiting_for_online = true # Hold food and the song clock.
		judgment_label.text = "Online %s\nWaiting for both players..." % MEAL_NAMES[level_number - 1]
		# If the other phone drops, we hear about it here (deferred so the
		# network finishes its current work before we change scenes).
		multiplayer.peer_disconnected.connect(_on_online_peer_left, CONNECT_DEFERRED)
		multiplayer.server_disconnected.connect(_on_online_server_left, CONNECT_DEFERRED)
		Net.both_players_loaded.connect(_on_both_players_loaded)
		Net.start_scheduled.connect(_on_start_scheduled)
		create_online_hud()
		Net.opponent_stats_updated.connect(_on_opponent_stats_updated)
		Net.online_match_finished.connect(_on_online_match_finished)
		Net.attack_received.connect(_on_attack_received)
		Net.report_level_loaded.rpc_id(1) # Report readiness to the host.
	else:
		await start_countdown() # Start offline modes normally.
		
	print("Breakfast playable notes: ", breakfast_notes.size())
	print("First playable note: ", breakfast_notes[0])
	# Check that we loaded the expected song and notes.
	print("Chart BPM: ", chart["bpm"])
	print("Melody notes: ", chart["lead_notes"].size())
	print("First note: ", chart["lead_notes"][0])
	
func _process(_delta: float) -> void:
	if finished:
		return

	if GameState.mode == "online" and not music_started:
		update_online_countdown()

	if waiting_for_online:
		return # Stay frozen until the scheduled countdown begins.
		
	song_time = read_song_time() # Works during countdown and playback.
	update_cpu() # Evaluate notes whose arrival time has passed.	
	
	if cpu != null:
		cpu_label.text = "CPU score: %d\nCPU lives: %d" % [
		cpu.score, cpu.lives
		]
		
	for food in active_food:
		food.update_from_song(song_time, get_viewport_rect().size.x)
		food.judge_catch(song_time, int(catcher.get("lane")))

	send_online_stats() # Share any changes made by those judgments.

	var beat: int = floori(song_time * bpm / 60.0)

	# Both sides have now evaluated the current song time.
	if cpu != null and (lives <= 0 or cpu.lives <= 0):
		end_cpu_match()
		return	

	if beat > last_beat:
		last_beat = beat # Print only when we reach a new beat.
		print("Beat ", beat + 1) # Show human-friendly numbering from 1.

func _on_food_judgment(result: String) -> void:
	if finished or lives <= 0:
		return # An eliminated player cannot earn further points.

	if result == "HIT_BAD":
		lives = maxi(0, lives - 1) # Lose exactly one life.
		judgment_label.text = "ROTTEN!\nLives: %d" % lives
		if lives == 0 and cpu == null:
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
		if GameState.mode == "online" and combo % THROW_COMBO == 0:
			throw_attack() # Combo of 10, 20, 30... sends rotten food.

	update_throw_meter()

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
	if cpu != null:
		end_cpu_match() # Compare surviving players' scores.
	else:
		end_attempt(caught_count >= TARGET_CATCHES and lives > 0)


func end_attempt(won: bool) -> void:
	if finished:
		return # End the attempt only once.

	finished = true # Block further gameplay results.
	music.stop() # Stop music when losing before the song ends.

	if GameState.mode == "online":
		judgment_label.text = "You finished!\nWaiting for opponent..."
		send_online_stats() # Make sure the rival sees our last numbers.
		Net.report_match_finished.rpc_id(1, score, lives) # Tell the host.
		# Don't wait forever: give up a little after the rival's song must have ended.
		var song_left: float = music.stream.get_length() - maxf(song_time, 0.0)
		get_tree().create_timer(song_left + RESULT_WAIT_EXTRA).timeout.connect(
			_on_result_wait_timeout
		)
		return # The host's answer arrives in _on_online_match_finished().

	# A win earns one star per remaining life; a loss earns none.
	var stars: int = lives if won else 0
	
	if won and GameState.mode == "solo":
		# Only Solo clears update campaign unlocks and best stars.
		GameState.complete_level(level_number, stars)

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
		"level_path": scene_file_path,
		"mode": GameState.mode, # Remember which mode produced this result.
		"cpu_score": cpu.score if cpu != null else 0,
		"cpu_lives": cpu.lives if cpu != null else 0,
		"cpu_outcome": cpu_outcome,
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
		
		if food.is_bad:
			cpu.judge_bad_note() # Simulate avoiding this rotten food.
		else:
			cpu.judge_good_note() # Simulate catching this good food.
			

func create_cpu_hud() -> void:
	cpu_label = Label.new() # Create a text label.
	cpu_label.position = Vector2(24, 420) # Below the player's counters.
	cpu_label.add_theme_font_size_override("font_size", 32)
	cpu_label.add_theme_color_override("font_color", Color("#2667B0"))
	$HUD.add_child(cpu_label) # Put it on the interface layer.


func end_cpu_match() -> void:
	if finished:
		return # Resolve this match only once.

	cpu_outcome = "DRAW"
	if lives > 0 and cpu.lives <= 0:
		cpu_outcome = "YOU WIN" # Only you survived.
	elif lives <= 0 and cpu.lives > 0:
		cpu_outcome = "CPU WINS" # Only the CPU survived.
	elif score > cpu.score:
		cpu_outcome = "YOU WIN"
	elif score < cpu.score:
		cpu_outcome = "CPU WINS"

	end_attempt(cpu_outcome == "YOU WIN") # Open Result.

func _on_both_players_loaded() -> void:
	if Net.is_host:
		Net.client_clock_ready.connect(_on_client_clock_ready)
		judgment_label.text = "Both players loaded!\nWaiting for clock check..."
	else:
		judgment_label.text = "Checking host clock..."
		Net.clock_sampled.connect(_on_clock_sampled)
		Net.begin_clock_check()
		
func _on_clock_sampled() -> void:
	judgment_label.text = "Clock check complete! (%d samples)\nBest round trip: %d ms\nOffset: %.1f ms" % [
		Net.clock_samples_received,
		Net.clock_roundtrip_ms,
		Net.host_clock_offset_ms
	]
	Net.report_clock_ready.rpc_id(1) # Tell the host we're ready.

func _on_client_clock_ready() -> void:
	if not Net.is_host or online_music_start_ms >= 0.0:
		return # Only the host schedules, once per level.

	# Allow one second for delivery, then three seconds of countdown.
	Net.schedule_start.rpc(Time.get_ticks_msec() + 4000)
	
func _on_start_scheduled(host_music_start_ms: int) -> void:
	if online_music_start_ms >= 0.0:
		return # Ignore duplicate schedules.

	online_music_start_ms = float(host_music_start_ms)
	if not Net.is_host:
		# Host time = client time + offset, so subtract to convert back.
		online_music_start_ms -= Net.host_clock_offset_ms

	countdown_start_ms = roundi(online_music_start_ms - 3000.0)
	judgment_label.text = "Get ready!"
	
func update_online_countdown() -> void:
	if online_music_start_ms < 0.0:
		return # No schedule received yet.

	var remaining_ms: float = online_music_start_ms - Time.get_ticks_msec()
	if remaining_ms > 3000.0:
		return # Keep gameplay frozen until the countdown begins.

	waiting_for_online = false # Let food move during the countdown.

	if remaining_ms > 0.0:
		judgment_label.text = str(ceili(remaining_ms / 1000.0))
	else:
		judgment_label.text = "Goal: catch %d bites!" % TARGET_CATCHES
		music_started = true
		# If this frame is slightly late, begin at the matching song position.
		music.play(maxf(0.0, -remaining_ms / 1000.0))

func create_online_hud() -> void:
	opponent_label = Label.new()
	opponent_label.position = Vector2(24, 420)
	opponent_label.add_theme_font_size_override("font_size", 32)
	opponent_label.add_theme_color_override("font_color", Color("#2667B0"))
	opponent_label.text = "Opponent score: 0\nOpponent lives: 3"
	$HUD.add_child(opponent_label)

	throw_label = Label.new()
	throw_label.position = Vector2(24, 520) # Below the opponent's numbers.
	throw_label.add_theme_font_size_override("font_size", 32)
	throw_label.add_theme_color_override("font_color", Color("#D9468F"))
	$HUD.add_child(throw_label)
	update_throw_meter()

	incoming_label = Label.new()
	incoming_label.text = "INCOMING!"
	incoming_label.position = Vector2(0, 620)
	incoming_label.size = Vector2(720, 80) # Full width so the text is centered.
	incoming_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	incoming_label.add_theme_font_size_override("font_size", 64)
	incoming_label.add_theme_color_override("font_color", Color("#D9468F"))
	incoming_label.hide()
	$HUD.add_child(incoming_label)


# Shows how close the combo is to the next throw, e.g. "Throw [###-------] 3/10".
func update_throw_meter() -> void:
	if throw_label == null:
		return # Only online matches have a throw meter.
	var filled: int = combo % THROW_COMBO
	if filled == 0 and combo > 0:
		throw_label.text = "THROW! Rotten food sent!"
		return
	throw_label.text = "Throw [%s%s] %d/%d" % [
		"#".repeat(filled), "-".repeat(THROW_COMBO - filled), filled, THROW_COMBO
	]


func throw_attack() -> void:
	if Net.opponent_id == 0:
		return # Nobody to throw at.
	Net.send_attack.rpc_id(Net.opponent_id)


func _on_attack_received() -> void:
	if finished:
		return # Our match is already over.

	# Turn the next good food that's still far enough away rotten,
	# so the player has time to see it and dodge.
	for food in active_food:
		if food.judged or food.is_bad:
			continue
		if food.arrival_time < song_time + ATTACK_LEAD_TIME:
			continue
		food.make_rotten()
		show_incoming_warning()
		return
	# No food left in the song: the throw simply misses.


func show_incoming_warning() -> void:
	incoming_label.show()
	if incoming_tween != null:
		incoming_tween.kill() # A newer attack restarts the 1.5 s display.
	# A Tween belongs to the label, so it stops by itself if the scene closes.
	incoming_tween = incoming_label.create_tween()
	incoming_tween.tween_interval(1.5)
	incoming_tween.tween_callback(incoming_label.hide)


func _on_opponent_stats_updated(new_score: int, new_lives: int) -> void:
	opp_last_score = new_score
	opp_last_lives = new_lives
	opponent_label.text = "Opponent score: %d\nOpponent lives: %d" % [
		new_score, new_lives
	]


func send_online_stats() -> void:
	if GameState.mode != "online" or Net.opponent_id == 0:
		return

	if score == last_sent_score and lives == last_sent_lives:
		return # Nothing changed, so no message is needed.

	last_sent_score = score
	last_sent_lives = lives
	Net.receive_stats.rpc_id(Net.opponent_id, score, lives)

func _on_online_match_finished(my_score: int, my_lives: int, opp_score: int, opp_lives: int, outcome: String) -> void:
	if online_result_shown:
		return # Handle the host's final message only once.
	online_result_shown = true

	judgment_label.text = "%s\nYou: %d  Rival: %d" % [outcome, my_score, opp_score]

	# Save the host-confirmed numbers so Result can show them.
	GameState.last_result = {
		"won": outcome == "YOU WIN!",
		"stars": 0, # Stars are a Solo-only reward.
		"score": my_score,
		"caught": caught_count,
		"goal": TARGET_CATCHES,
		"lives": my_lives,
		"judgments": judgment_counts.duplicate(),
		"max_combo": max_combo,
		"level_path": scene_file_path,
		"mode": "online",
		"online_outcome": outcome,
		"opp_score": opp_score,
		"opp_lives": opp_lives,
	}

	# Let both players read the outcome briefly before switching screens.
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/ui/result.tscn")


func _on_online_peer_left(_peer_id: int) -> void:
	end_online_early("OPPONENT LEFT", "Opponent left the match.")


func _on_online_server_left() -> void:
	end_online_early("OPPONENT LEFT", "Host left the match.")


func _on_result_wait_timeout() -> void:
	end_online_early("NO RESULT", "Opponent never sent a final score.")


# Ends an online match without the host's normal final result.
func end_online_early(outcome: String, message: String) -> void:
	if online_result_shown:
		return # The match already ended (normal result or earlier disconnect).
	online_result_shown = true
	finished = true # Freeze gameplay.
	waiting_for_online = false
	music.stop()
	Net.leave_game() # Close the broken connection right away.
	judgment_label.text = "%s\n%s" % [outcome, message]

	await get_tree().create_timer(2.0).timeout

	if not music_started:
		# Nothing was played yet, so go straight back to the lobby.
		Net.lobby_message = message
		get_tree().change_scene_to_file("res://scenes/ui/Lobby.tscn")
		return

	# Show what we had when the match stopped; no winner is decided.
	GameState.last_result = {
		"won": false,
		"stars": 0,
		"score": score,
		"caught": caught_count,
		"goal": TARGET_CATCHES,
		"lives": lives,
		"judgments": judgment_counts.duplicate(),
		"max_combo": max_combo,
		"level_path": scene_file_path,
		"mode": "online",
		"online_outcome": outcome,
		"opp_score": opp_last_score,
		"opp_lives": opp_last_lives,
	}
	get_tree().change_scene_to_file("res://scenes/ui/result.tscn")
