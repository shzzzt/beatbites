extends Control
# Title screen: tap anywhere to start. Sound and Credits live on the
# mode select screen, as in the mockup.
#
# Animations (all Tweens, which Godot frees with the scene):
#   1. Intro: BEAT and BITES drop in with a bounce, then the rest fades in.
#   2. Idle:  the logo words and the food float up and down.
#   3. Beat:  the axolotl hops on every beat of the menu song (80 BPM).
#   4. Exit:  the screen fades out when you tap.

const MENU_BPM: float = 80.0 # Tempo of music_menu.ogg ("A Table Under the Stars").
const CATCH_TEXTURE = preload("res://assets/art/catcher_catch.png")
const IDLE_TEXTURE = preload("res://assets/art/catcher_idle.png")

@onready var beat_word: Array[Label] = [$Margin/Content/Beat/Front, $Margin/Content/Beat/Back]
@onready var bites_word: Array[Label] = [$Margin/Content/Bites/Front, $Margin/Content/Bites/Back]
@onready var tagline: Label = $Margin/Content/Tagline
@onready var art: Control = $Margin/Content/Art
@onready var foods: Array[TextureRect] = [
	$Margin/Content/Art/Apple, $Margin/Content/Art/Berry, $Margin/Content/Art/Donut
]
@onready var catcher: TextureRect = $Margin/Content/Art/Catcher
@onready var tap_row: HBoxContainer = %TapRow
@onready var version: Label = $Margin/Content/Version
@onready var music: AudioStreamPlayer = $MenuMusic

var starting: bool = false # Taps can arrive as touch + mouse; start once.
var intro_done: bool = false # Beat hops wait until the intro has finished.
var last_beat: int = -1 # The last beat the axolotl hopped on.
var start_ms: int = 0 # Fallback clock if the music isn't playing.
var catcher_base_y: float = 0.0


func _ready() -> void:
	# The root Control receives every tap because all its children ignore input.
	gui_input.connect(_on_gui_input)
	start_ms = Time.get_ticks_msec()
	catcher_base_y = catcher.position.y
	play_intro()


# --- 1. Intro ---------------------------------------------------------------

func play_intro() -> void:
	# Hide everything that fades in, and lift the logo words off screen.
	for node: CanvasItem in [tagline, art, tap_row, version]:
		node.modulate.a = 0.0
	for label in beat_word + bites_word:
		label.position.y -= 320.0

	# set_parallel(true) runs every step at the same time; each step's
	# set_delay() decides when it actually starts.
	var intro: Tween = create_tween().set_parallel(true)
	for label in beat_word:
		intro.tween_property(label, "position:y", label.position.y + 320.0, 0.9) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	for label in bites_word:
		intro.tween_property(label, "position:y", label.position.y + 320.0, 0.9) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(0.15)
	intro.tween_property(tagline, "modulate:a", 1.0, 0.4).set_delay(0.7)
	intro.tween_property(art, "modulate:a", 1.0, 0.5).set_delay(0.9)
	intro.tween_property(version, "modulate:a", 1.0, 0.4).set_delay(1.1)
	intro.tween_property(tap_row, "modulate:a", 1.0, 0.3).set_delay(1.3)
	# chain() goes back to "one after another": run this once all of the above end.
	intro.chain().tween_callback(start_idle_animations)


# --- 2. Idle loops ----------------------------------------------------------

func start_idle_animations() -> void:
	intro_done = true
	float_nodes(beat_word, 8.0, 1.2, 0.0)
	float_nodes(bites_word, 8.0, 1.2, 0.6) # Half a cycle later than BEAT.
	for i in foods.size():
		float_nodes([foods[i]], 12.0, 0.9 + i * 0.15, i * 0.3)

	# Blink "TAP TO START" forever.
	var blink: Tween = create_tween().set_loops()
	blink.tween_property(tap_row, "modulate:a", 0.35, 0.6)
	blink.tween_property(tap_row, "modulate:a", 1.0, 0.6)


# Moves the given nodes up by `amount` px and back down, forever, starting
# after `delay` seconds. Nodes in one call move together (e.g. a word and its
# shadow label).
func float_nodes(nodes: Array, amount: float, half_period: float, delay: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void:
		var loop: Tween = create_tween().set_loops()
		# Step 1: every node moves up at the same time...
		for i in nodes.size():
			var node: Control = nodes[i]
			add_float_step(loop, node, node.position.y - amount, half_period, i > 0)
		# Step 2: ...then they all move back down together.
		for i in nodes.size():
			var node: Control = nodes[i]
			add_float_step(loop, node, node.position.y, half_period, i > 0)
	)


# Adds one smooth up/down move to `loop`. `with_previous` = run at the same
# time as the step before it (Tween.parallel()) instead of after it.
func add_float_step(loop: Tween, node: Control, y: float, time: float, with_previous: bool) -> void:
	if with_previous:
		loop.parallel()
	loop.tween_property(node, "position:y", y, time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# --- 3. Hop on the beat -----------------------------------------------------

func _process(_delta: float) -> void:
	if not intro_done or starting:
		return

	var beat: int = floori(song_time() * MENU_BPM / 60.0)
	if beat < last_beat:
		last_beat = -1 # The song looped back to the start; count beats again.
	if beat > last_beat:
		last_beat = beat
		hop()


# Same audio clock idea as gameplay, so the hop stays on the music's beat.
func song_time() -> float:
	if music.playing:
		return music.get_playback_position() + AudioServer.get_time_since_last_mix()
	return (Time.get_ticks_msec() - start_ms) / 1000.0 # Song ended: keep a steady beat.


func hop() -> void:
	catcher.texture = CATCH_TEXTURE
	var tween: Tween = create_tween()
	tween.tween_property(catcher, "position:y", catcher_base_y - 24.0, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(catcher, "position:y", catcher_base_y, 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: catcher.texture = IDLE_TEXTURE)


# --- 4. Tap to start --------------------------------------------------------

func _on_gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if tapped:
		start_game()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		start_game() # Enter/Space also work when testing on a PC.


func start_game() -> void:
	if starting:
		return
	starting = true
	var fade: Tween = create_tween().set_parallel(true)
	fade.tween_property(self, "modulate:a", 0.0, 0.25)
	fade.tween_property(music, "volume_db", -30.0, 0.25)
	fade.chain().tween_callback(func() -> void:
		get_tree().change_scene_to_file("res://scenes/ui/ModeSelect.tscn")
	)
