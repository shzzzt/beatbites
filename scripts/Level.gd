extends Node2D

@export var level_number: int = 1 # Breakfast = 1, Lunch = 2, etc.
@export_file("*.json") var chart_path: String = \
	"res://assets/audio/music_breakfast.json" # Chart used by this level.
@export_range(3, 5, 1) var lane_count: int = 3 # Harder meals have more lanes.
# Seconds a food takes to fall onto the axolotl. Shorter = faster drops and
# more space between bites (Breakfast 2.4 → Dessert 1.2).
@export_range(1.0, 3.0, 0.1) var fall_time: float = 2.4
# Which notes may become food: 1 = whole beats only, 2 = also half beats,
# 4 = also quarter beats (like the off-beat "¾" notes in Dinner).
@export_range(1, 4, 1) var notes_per_beat: int = 1
# Minimum seconds between two foods, so bites never fall in a tight stream.
# Whole-beat notes are kept first; off-beat notes only fill gaps. 0 = keep all.
@export_range(0.0, 1.0, 0.05) var min_gap: float = 0.0

var last_sent_score: int = -1
var last_sent_lives: int = -1
var online_music_start_ms: float = -1.0 # Deadline on this phone's clock.
var waiting_for_online: bool = false # Freeze gameplay until both phones are ready.
var online_result_shown: bool = false # The online match has ended (result or disconnect).
var opp_last_score: int = 0 # Rival's latest numbers, kept in case they disconnect.
var opp_last_lives: int = 3
const RESULT_WAIT_EXTRA: float = 15.0 # Seconds to wait past the song's end for the rival.
# VS CPU / Online: every 10th food (the 5th, 15th, 25th…) is a glowing power
# food. Its kind is picked from this list (THROW is listed 3 times, so it's the
# most common). The same seed on both phones gives the same power foods.
const POWER_EVERY: int = 10
const POWER_OFFSET: int = 4
const POWER_KINDS: Array[String] = ["rotten", "rotten", "rotten", "ink", "ink", "shield", "double", "life"]
const MAX_LIVES: int = 3
const FULL_LIFE_BONUS: int = 200 # HEART caught with full lives gives points instead.
const HAZARD_COUNT: int = 3 # Rotten foods tossed onto the rival's field by THROW.
const HAZARD_REACT_TIME: float = 0.7 # A tossed hazard lands at least this long before reaching the catcher.
const INK_TIME: float = 4.0 # Seconds the INK blobs stay on the field.
const DOUBLE_TIME: float = 6.0 # Seconds of double points from x2.
var hazards: Array[FallingFood] = [] # Rotten foods the rival tossed onto our field.
var has_shield: bool = false # SHIELD power: blocks the next attack.
var double_until: float = -INF # x2 power: song time when double points end.
var sfx: Sfx # Sound effects player (created in setup_hud).
const CPU_SOUND_DB: float = -6.0 # The CPU's own power sounds are quieter than ours.
const PAUSE_SCENE = preload("res://scenes/ui/PauseMenu.tscn")
const HUD_SCENE = preload("res://scenes/ui/GameHUD.tscn")
const BACKDROP_SCENE = preload("res://scenes/ui/GameBackdrop.tscn")
var pause_menu: PauseMenu
var hud: GameHUD # Score, lives, goal bar, rival panel, pop-up text.
var pause_started_ms: int = 0 # When the current pause began.
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
var cpu_outcome: String = "" # Final CPU match message.


@onready var music: AudioStreamPlayer = $Music # Find our Music child.
@onready var output_latency: float = AudioServer.get_output_latency()
@onready var catcher: Catcher = $Catcher # Find the catcher in this level.

func _ready() -> void:
	# Read the chart file as text.
	var text: String = FileAccess.get_file_as_string(chart_path)
	# Convert JSON text into data we can access by name.
	var chart: Dictionary = JSON.parse_string(text)
		# Build our playable list before spawning any food.
	bpm = float(chart["bpm"]) # Use this song's exact tempo.

	breakfast_notes = pick_notes(chart["lead_notes"])
	assign_lanes(breakfast_notes) # Give every note a lane from the melody's shape.
	catcher.setup(lane_count)

	var food_index: int = 0 # Count foods as we create them.
	# Pick food pictures with a random generator seeded by the level number,
	# so the same meal always shows the same foods (on both phones online).
	var picker := RandomNumberGenerator.new()
	picker.seed = level_number
	var last_variant: int = -1
	var power_picker := RandomNumberGenerator.new() # Shuffles the power "bag".
	power_picker.seed = level_number + 1000
	var power_bag: Array[String] = []
	# Preview the chart after its opening three seconds.
	for note in breakfast_notes:
		var food: FallingFood = FOOD_SCENE.instantiate() as FallingFood
		# Snack onward: every tenth food is rotten.
		food.is_bad = level_number >= 3 and food_index % 10 == 9
		# VS CPU / Online: power foods (same ones on both phones, never rotten).
		if GameState.mode != "solo" and not food.is_bad and food_index % POWER_EVERY == POWER_OFFSET:
			if power_bag.is_empty():
				power_bag = shuffled_powers(power_picker) # Refill: every kind comes up again.
			food.power_kind = power_bag.pop_back()
		food_index += 1 # Advance to the next food number.
		# Random picture, but never the same food twice in a row.
		var variant: int = picker.randi_range(0, FallingFood.GOOD_TEXTURES.size() - 2)
		if variant >= last_variant and last_variant >= 0:
			variant += 1
		food.variant = variant
		last_variant = variant
		food.arrival_time = float(note["time"]) # Each gets its own timing.
		food.lane = int(note["lane"]) # Each gets its own lane.
		food.lane_count = lane_count
		food.fall_time = fall_time
		food.catch_y = catcher.position.y # Land on the axolotl exactly on the beat.
		food.hide() # Stay hidden until the fall begins.
		# bind() adds the food itself as an extra argument, so the handler
		# knows which food was judged (e.g. whether it was a power food).
		food.judgment_made.connect(_on_food_judgment.bind(food))
		add_child(food) # Put this instance into the level.
		active_food.append(food) # Remember it for updates.

	# End the attempt when the non-looping song finishes.
	music.finished.connect(_on_song_finished)
	setup_hud()
	setup_pause_menu()

	if GameState.mode == "cpu":
		cpu = CpuRival.new() # Create an independent rival.
		cpu.setup(level_number) # Accuracy rises each level (55% → 87%).
		refresh_hud()

	if GameState.mode == "online":
		waiting_for_online = true # Hold food and the song clock.
		hud.show_message("WAITING...", "Online %s · waiting for both players" % GameState.meal_name(level_number))
		# If the other phone drops, we hear about it here (deferred so the
		# network finishes its current work before we change scenes).
		multiplayer.peer_disconnected.connect(_on_online_peer_left, CONNECT_DEFERRED)
		multiplayer.server_disconnected.connect(_on_online_server_left, CONNECT_DEFERRED)
		Net.both_players_loaded.connect(_on_both_players_loaded)
		Net.start_scheduled.connect(_on_start_scheduled)
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
		refresh_hud() # The CPU's numbers change without a signal.

	var width: float = get_viewport_rect().size.x
	for food in active_food:
		food.update_from_song(song_time, width)
		food.judge_catch(song_time, catcher.lane)
	for hazard in hazards: # Rotten foods the rival tossed at us.
		hazard.update_from_song(song_time, width)
		hazard.judge_catch(song_time, catcher.lane)
	if GameState.mode != "solo":
		hud.set_status(has_shield, maxf(0.0, double_until - song_time))

	send_online_stats() # Share any changes made by those judgments.

	var beat: int = floori(song_time * bpm / 60.0)

	# Both sides have now evaluated the current song time.
	if cpu != null and (lives <= 0 or cpu.lives <= 0):
		end_cpu_match()
		return

	if beat > last_beat:
		last_beat = beat # Print only when we reach a new beat.
		print("Beat ", beat + 1) # Show human-friendly numbering from 1.

func _on_food_judgment(result: String, food: FallingFood) -> void:
	if finished or lives <= 0:
		return # An eliminated player cannot earn further points.

	if result == "HIT_BAD":
		lives = maxi(0, lives - 1) # Lose exactly one life.
		sfx.play("bonk")
		hud.show_judgment("ROTTEN!", 0)
		refresh_hud()
		if lives == 0 and cpu == null:
			end_attempt(false) # Lose immediately, regardless of score.
		return

	if result == "AVOIDED":
		hud.show_judgment("DODGED!", combo)
		return # Avoiding rotten food isn't a MISS.

	judgment_counts[result] += 1 # Count this food's judgment once.
	if result == "MISS":
		combo = 0 # A missed good food breaks the streak.
	else:
		combo += 1 # PERFECT and GOOD both continue the streak.
		max_combo = maxi(max_combo, combo) # Keep the highest streak.
		caught_count += 1 # Both count toward the catch goal.
		var points: int = 100 if result == "PERFECT" else 50 # GOOD earns fewer points.
		if song_time < double_until:
			points *= 2 # x2 power is active.
		score += points
		if food.power_kind != "":
			use_power(food.power_kind) # Caught a power food!

	# Show the result in the middle and update the HUD numbers.
	hud.show_judgment(result, combo)
	refresh_hud()

# Choose which melody notes become food.
#  1. Only notes on the allowed grid (notes_per_beat): e.g. with 2, a note on
#     beat 3.5 is allowed (3.5 × 2 = 7, a whole number) but 3.75 is not.
#  2. Whole-beat notes are kept first, then off-beat notes, and a note is
#     skipped if it is closer than min_gap seconds to any food already kept.
#     So off-beat notes only fill empty spaces and never make a tight stream.
func pick_notes(lead_notes: Array) -> Array[Dictionary]:
	var on_beat: Array[Dictionary] = []
	var off_beat: Array[Dictionary] = []
	for note in lead_notes:
		var beat: float = float(note["beat"])
		var grid_position: float = beat * notes_per_beat
		if not is_equal_approx(grid_position, roundf(grid_position)):
			continue
		var entry: Dictionary = {
			"time": beat * 60.0 / bpm, # Convert using this song's tempo.
			"midi": int(note["midi"]), # Original pitch.
		}
		if is_equal_approx(beat, roundf(beat)):
			on_beat.append(entry)
		else:
			off_beat.append(entry)

	var kept: Array[Dictionary] = []
	for entry in on_beat + off_beat:
		var fits: bool = true
		for other in kept:
			if absf(entry["time"] - other["time"]) < min_gap - 0.001:
				fits = false # Too close to a food we already have.
				break
		if fits:
			kept.append(entry)
	# Back into song order (off-beat notes were added last).
	kept.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["time"] < b["time"])
	return kept


# Lanes follow the melody's shape instead of its exact pitch (exact pitch
# made long runs sit on one side):
#   - the note goes up   -> move right; goes down -> move left; same -> stay
#     (Breakfast and Lunch only move on steps of 2+ semitones)
#   - a big jump (more than 4 semitones) moves 2 lanes when there are 4+ lanes
#   - hitting a wall bounces back toward the middle
#   - after 3 notes in the same lane, the next one moves toward the center,
#     so the player never camps on one side for long.
# Same input always gives the same lanes, so both phones match online.
const MAX_SAME_LANE: int = 3

func assign_lanes(notes: Array[Dictionary]) -> void:
	var last_lane: int = lane_count - 1
	var center: float = last_lane / 2.0
	var lane: int = floori(center)
	var previous_midi: int = -1
	var same_lane_run: int = 0
	for note in notes:
		var midi: int = note["midi"]
		if previous_midi >= 0:
			var jump: int = midi - previous_midi
			var step: int = 0
			# Breakfast and Lunch ignore 1-semitone steps, so they move a bit less.
			var min_jump: int = 2 if level_number <= 2 else 1
			if absi(jump) >= min_jump:
				step = 2 if absi(jump) > 4 and lane_count >= 4 else 1
				step *= signi(jump)
			var new_lane: int = lane + step
			if new_lane > last_lane:
				new_lane = last_lane - (new_lane - last_lane) # Bounce off the right wall.
			elif new_lane < 0:
				new_lane = -new_lane # Bounce off the left wall.
			if new_lane == lane:
				same_lane_run += 1 # Count notes repeated in this lane.
				if same_lane_run >= MAX_SAME_LANE and not is_equal_approx(lane, center):
					new_lane = lane + (1 if lane < center else -1) # Drift to the middle.
			new_lane = clampi(new_lane, 0, last_lane)
			if new_lane != lane:
				same_lane_run = 0 # Moved, so start counting again.
			lane = new_lane
		note["lane"] = lane
		previous_midi = midi

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
	if GameState.mode != "online":
		pause_menu.disable() # Online keeps the menu so a waiting player can leave.

	if GameState.mode == "online":
		hud.show_message("YOU FINISHED!", "Waiting for your rival...")
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
	var unlocked_before: int = GameState.unlocked_level

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
		"level_number": level_number, # Lets Result offer NEXT MEAL.
		"newly_unlocked": GameState.unlocked_level > unlocked_before, # Unlock banner.
		"mode": GameState.mode, # Remember which mode produced this result.
		"cpu_score": cpu.score if cpu != null else 0,
		"cpu_lives": cpu.lives if cpu != null else 0,
		"cpu_outcome": cpu_outcome,
	}
	# Switch after the current food callbacks finish.
	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/result.tscn")

func start_countdown() -> void:
	countdown_start_ms = Time.get_ticks_msec() # Read the elapsed-time clock.
	# Count backward: 3, 2, 1. The goal is shown underneath (R2).
	for number in range(3, 0, -1):
		hud.show_message(str(number), "Goal: catch %d bites!" % TARGET_CATCHES, true)
		# Wait one second; this timer will respect a future pause.
		await get_tree().create_timer(1.0, false).timeout

	hud.show_message("GO!", "Goal: catch %d bites!" % TARGET_CATCHES, true, 0.8)
	music_started = true # The countdown has finished.
	music.play() # Begin playback from the start.

func read_song_time() -> float:
	# Settings > Audio delay: shift the whole clock back if the player hears
	# the music late (0 by default, so nothing changes unless they set it).
	var offset: float = GameState.timing_offset_ms / 1000.0

	if music.playing:
		# Use the audio clock once playback starts.
		var clock: float = music.get_playback_position()
		clock += AudioServer.get_time_since_last_mix()
		clock -= output_latency
		clock -= offset
		return maxf(song_time, clock) # Prevent backward jumps.

	if music_started:
		return song_time # Hold the clock when playback ends.

	# Before music starts, advance from -3 toward zero.
	var elapsed: float = (Time.get_ticks_msec() - countdown_start_ms) / 1000.0
	# Let audio determine the zero crossing; the same offset keeps it continuous.
	return minf(-0.001, elapsed - 3.0) - offset


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
		elif cpu.judge_good_note(song_time) and food.power_kind != "":
			cpu_use_power(food.power_kind) # The CPU caught a power food.
		if cpu.incoming > 0:
			# Rotten foods we tossed at the CPU: one extra dodge test per food.
			cpu.incoming -= 1
			cpu.judge_bad_note()


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


# --- HUD --------------------------------------------------------------------

func setup_hud() -> void:
	var backdrop: CanvasLayer = BACKDROP_SCENE.instantiate() # GameBackdrop.gd
	backdrop.lane_count = lane_count # Draw one dashed line between each pair of lanes.
	add_child(backdrop) # Sparkles, lane lines, catch line.
	hud = HUD_SCENE.instantiate() as GameHUD
	$HUD.add_child(hud) # The HUD CanvasLayer draws above the food.
	hud.setup(GameState.mode, level_number, GameState.meal_name(level_number))
	sfx = Sfx.new() # Sound effects (power foods, throws, rotten food).
	add_child(sfx)
	hud.sfx = sfx # The HUD plays sounds at the exact moment of each animation.
	refresh_hud()


# Push every number to the HUD (cheap, so we just do it whenever one changes).
func refresh_hud() -> void:
	hud.set_score(score)
	hud.set_lives(lives)
	hud.set_goal(caught_count, TARGET_CATCHES)
	if cpu != null:
		hud.set_versus(score, lives, cpu.score, cpu.lives)
	elif GameState.mode == "online":
		hud.set_versus(score, lives, opp_last_score, opp_last_lives)


# --- Online -----------------------------------------------------------------

func _on_both_players_loaded() -> void:
	if Net.is_host:
		Net.client_clock_ready.connect(_on_client_clock_ready)
		hud.show_message("SYNCING...", "Both players loaded · checking clocks")
	else:
		hud.show_message("SYNCING...", "Checking the host's clock")
		Net.clock_sampled.connect(_on_clock_sampled)
		Net.begin_clock_check()

func _on_clock_sampled() -> void:
	hud.show_message("SYNCED!", "Clock offset %.1f ms · round trip %d ms" % [
		Net.host_clock_offset_ms, Net.clock_roundtrip_ms
	])
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
	hud.show_message("GET READY!")

func update_online_countdown() -> void:
	if online_music_start_ms < 0.0:
		return # No schedule received yet.

	var remaining_ms: float = online_music_start_ms - Time.get_ticks_msec()
	if remaining_ms > 3000.0:
		return # Keep gameplay frozen until the countdown begins.

	waiting_for_online = false # Let food move during the countdown.

	if remaining_ms > 0.0:
		hud.show_message(str(ceili(remaining_ms / 1000.0)), "Catch more than your rival!", true)
	else:
		hud.show_message("GO!", "", true, 0.8)
		music_started = true
		# If this frame is slightly late, begin at the matching song position.
		music.play(maxf(0.0, -remaining_ms / 1000.0))


# --- Power foods (VS CPU and Online) -----------------------------------------
#   rotten (THROW): 3 rotten foods are tossed onto the rival's field
#   ink:            purple blobs cover part of the rival's field for 4 s
#   shield:         blocks the next attack thrown at you
#   double (x2):    double points for 6 s
#   life (HEART):   +1 life (max 3); with full lives, +200 points instead

# A shuffled copy of POWER_KINDS (a "bag"): dealing from a bag means every
# kind shows up regularly, instead of pure luck giving one meal no THROW at all.
# Uses our seeded generator (Array.shuffle() wouldn't be the same on both phones).
func shuffled_powers(rng: RandomNumberGenerator) -> Array[String]:
	var bag: Array[String] = POWER_KINDS.duplicate()
	for i in range(bag.size() - 1, 0, -1): # Fisher-Yates shuffle.
		var j: int = rng.randi_range(0, i)
		var swap: String = bag[i]
		bag[i] = bag[j]
		bag[j] = swap
	return bag


# We caught a power food.
func use_power(kind: String) -> void:
	match kind:
		"life":
			if lives < MAX_LIVES:
				lives += 1
				hud.show_power(catcher.position, "+1 LIFE!", kind)
			else:
				score += FULL_LIFE_BONUS
				hud.show_power(catcher.position, "+%d!" % FULL_LIFE_BONUS, kind)
			refresh_hud() # Show the new heart / score right away.
		"shield":
			has_shield = true
			hud.show_power(catcher.position, "SHIELD!", kind)
		"double":
			double_until = song_time + DOUBLE_TIME
			hud.show_power(catcher.position, "x2 POINTS!", kind)
		_: # "rotten" or "ink": attack the rival.
			var blocked: bool = false
			if cpu != null:
				if cpu.shield:
					cpu.shield = false # The CPU's shield takes the hit.
					blocked = true
				elif kind == "rotten":
					cpu.incoming += HAZARD_COUNT
				else:
					cpu.ink_until = song_time + INK_TIME
			elif GameState.mode == "online" and Net.opponent_id != 0:
				# The rival's phone decides if their shield blocks it.
				Net.send_attack.rpc_id(Net.opponent_id, kind)
			hud.play_throw(catcher.position, kind, blocked)


# The CPU caught a power food.
func cpu_use_power(kind: String) -> void:
	match kind:
		"shield":
			cpu.shield = true
			sfx.play("shield", CPU_SOUND_DB)
			hud.show_rival_power("CPU SHIELD!")
		"double":
			cpu.double_until = song_time + DOUBLE_TIME
			sfx.play("double", CPU_SOUND_DB)
			hud.show_rival_power("CPU x2!")
		"life":
			sfx.play("heart", CPU_SOUND_DB)
			if cpu.lives < MAX_LIVES:
				cpu.lives += 1
				hud.show_rival_power("CPU +1 LIFE!")
			else:
				cpu.score += FULL_LIFE_BONUS
				hud.show_rival_power("CPU +%d!" % FULL_LIFE_BONUS)
		_:
			receive_attack(kind)


func _on_attack_received(kind: String) -> void:
	receive_attack(kind) # The online rival caught a THROW or INK power.


# The rival attacked us with "rotten" or "ink".
func receive_attack(kind: String) -> void:
	if finished:
		return # Our match is already over.
	hud.play_warning(kind)
	if has_shield:
		has_shield = false
		hud.play_blocked(catcher.position + Vector2(0, -80))
		return
	if kind == "ink":
		hud.play_ink_hit(INK_TIME)
		get_tree().create_timer(GameHUD.FLIGHT_TIME, false).timeout.connect(shake_screen)
	else:
		spawn_hazards(HAZARD_COUNT)


# Tosses rotten foods onto our field at random: each gets a random lane and a
# random (on-the-beat) landing time, but never right on top of another food in
# the same lane, and always early enough that you can still dodge it.
func spawn_hazards(count: int) -> void:
	var step: float = 60.0 / bpm / 2.0 # Half-beat grid, so hazards still hit the rhythm.
	var width: float = get_viewport_rect().size.x
	for i in count:
		var delay: float = i * 0.15 # Staggered, one after another.
		var impact: float = song_time + delay + GameHUD.FLIGHT_TIME
		var earliest: float = impact + HAZARD_REACT_TIME
		var latest: float = maxf(earliest, impact + fall_time * 0.85) # Still on screen.
		for attempt in 16: # Try random spots until one is free.
			var arrival: float = ceilf(randf_range(earliest, latest) / step) * step
			var lane: int = randi() % lane_count
			if not spot_is_free(arrival, lane):
				continue
			var hazard: FallingFood = make_hazard(arrival, lane)
			hud.toss_rotten(delay, hazard.position_at(impact, width), _hazard_lands.bind(hazard))
			break


func spot_is_free(arrival: float, lane: int) -> bool:
	for food in active_food + hazards:
		if not food.judged and food.lane == lane and absf(food.arrival_time - arrival) < 0.3:
			return false
	return true


func make_hazard(arrival: float, lane: int) -> FallingFood:
	var hazard: FallingFood = FOOD_SCENE.instantiate() as FallingFood
	hazard.is_bad = true
	hazard.variant = randi() % FallingFood.BAD_TEXTURES.size()
	hazard.arrival_time = arrival
	hazard.lane = lane
	hazard.lane_count = lane_count
	hazard.fall_time = fall_time
	hazard.catch_y = catcher.position.y
	hazard.waiting_to_land = true # Hidden until the toss animation reaches it.
	hazard.hide()
	hazard.judgment_made.connect(_on_food_judgment.bind(hazard))
	add_child(hazard)
	hazards.append(hazard)
	return hazard


func _hazard_lands(hazard: FallingFood) -> void:
	if finished:
		return
	hazard.land()
	shake_screen()


# Shakes the food and the catcher for a moment (the HUD stays still).
func shake_screen() -> void:
	var tween := create_tween()
	for offset in [Vector2(10, 6), Vector2(-8, -4), Vector2(6, 3), Vector2(-3, -2), Vector2.ZERO]:
		tween.tween_property(self, "position", offset, 0.04)


func _on_opponent_stats_updated(new_score: int, new_lives: int) -> void:
	opp_last_score = new_score
	opp_last_lives = new_lives
	refresh_hud()


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
	pause_menu.disable()

	hud.show_message(outcome, "You %d · Rival %d" % [my_score, opp_score])

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
		"level_number": level_number,
		"mode": "online",
		"online_outcome": outcome,
		"opp_score": opp_score,
		"opp_lives": opp_lives,
		"opp_name": Net.opponent_name,
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
	pause_menu.disable()
	music.stop()
	var rival_name: String = Net.opponent_name # leave_game() clears it.
	Net.leave_game() # Close the broken connection right away.
	hud.show_message(outcome, message)

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
		"level_number": level_number,
		"mode": "online",
		"online_outcome": outcome,
		"opp_score": opp_last_score,
		"opp_lives": opp_last_lives,
		"opp_name": rival_name,
	}
	get_tree().change_scene_to_file("res://scenes/ui/result.tscn")


# --- Pause ------------------------------------------------------------------

func setup_pause_menu() -> void:
	pause_menu = PAUSE_SCENE.instantiate() as PauseMenu
	pause_menu.online = GameState.mode == "online" # Set before _ready runs.
	add_child(pause_menu)
	pause_menu.opened.connect(_on_pause_opened)
	pause_menu.resumed.connect(_on_pause_resumed)
	pause_menu.restart_requested.connect(_on_pause_restart)
	pause_menu.quit_requested.connect(_on_pause_quit)


func _on_pause_opened() -> void:
	pause_menu.set_info("LV %d · %s · %d / %d bites" % [
		level_number, GameState.meal_name(level_number), caught_count, TARGET_CATCHES
	])
	if GameState.mode == "online":
		return # We can't freeze the other phone, so the match keeps going.
	pause_started_ms = Time.get_ticks_msec()
	music.stream_paused = true # Hold the song at its current position.
	# Stops _process, food, the catcher and countdown timers. The pause menu
	# keeps working because its process_mode is "Always".
	get_tree().paused = true


func _on_pause_resumed() -> void:
	if GameState.mode == "online":
		return
	get_tree().paused = false
	music.stream_paused = false
	if not music_started:
		# The countdown clock uses real time, so skip the time spent paused.
		countdown_start_ms += Time.get_ticks_msec() - pause_started_ms


func _on_pause_restart() -> void:
	get_tree().paused = false # Pausing would otherwise carry into the new scene.
	get_tree().reload_current_scene()


func _on_pause_quit() -> void:
	get_tree().paused = false
	if GameState.mode == "online":
		online_result_shown = true # Ignore the disconnect we're about to cause.
		finished = true
		Net.leave_game() # The rival sees "OPPONENT LEFT".
		Net.lobby_message = "You left the match."
		get_tree().change_scene_to_file("res://scenes/ui/Lobby.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/ui/LevelSelect.tscn")
