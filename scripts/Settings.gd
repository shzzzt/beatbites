extends Control
# Settings: sound on/off, volume, audio delay (timing calibration) and
# reset progress. Everything is saved by GameState right away.

const SOUND_ON_COLOR := Color("#3E7A12")
const SOUND_OFF_COLOR := Color("#B02C6C")
const OFFSET_STEP: int = 10 # ms per tap on - / +.
const RESET_CONFIRM_TIME: float = 3.0 # Seconds the "TAP AGAIN" state lasts.

var reset_armed: bool = false # True after the first tap on RESET.
var reset_tween: Tween


func _ready() -> void:
	%Back.pressed.connect(_on_back_pressed)
	%Sound.pressed.connect(_on_sound_pressed)
	%Volume.value = roundf(GameState.volume * 100.0)
	# Connect after setting the starting value, so loading doesn't trigger a save.
	%Volume.value_changed.connect(_on_volume_changed)
	%Minus.pressed.connect(_change_offset.bind(-OFFSET_STEP))
	%Plus.pressed.connect(_change_offset.bind(OFFSET_STEP))
	%Reset.pressed.connect(_on_reset_pressed)
	update_sound_chip()
	update_volume_label()
	update_offset_label()
	update_progress_info()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/ModeSelect.tscn")


# --- Audio ------------------------------------------------------------------

func _on_sound_pressed() -> void:
	GameState.toggle_sound()
	update_sound_chip()


func update_sound_chip() -> void:
	%ChipText.text = "ON" if GameState.sound_on else "OFF"
	%ChipText.add_theme_color_override("font_color",
		SOUND_ON_COLOR if GameState.sound_on else SOUND_OFF_COLOR)


func _on_volume_changed(value: float) -> void:
	GameState.set_volume(value / 100.0)
	update_volume_label()


func update_volume_label() -> void:
	%VolumeValue.text = "%d%%" % roundi(GameState.volume * 100.0)


# --- Timing -----------------------------------------------------------------

func _change_offset(amount: int) -> void:
	GameState.set_timing_offset(GameState.timing_offset_ms + amount)
	update_offset_label()


func update_offset_label() -> void:
	var ms: int = GameState.timing_offset_ms
	%OffsetValue.text = ("+%d ms" % ms) if ms > 0 else ("%d ms" % ms)
	# Grey out a button at its limit so it's clear you can't go further.
	%Minus.disabled = ms <= -GameState.TIMING_OFFSET_LIMIT
	%Plus.disabled = ms >= GameState.TIMING_OFFSET_LIMIT


# --- Progress ---------------------------------------------------------------

func update_progress_info() -> void:
	%ProgressInfo.text = "%d / 15 stars · %d / 5 meals unlocked" % [
		GameState.total_stars(), GameState.unlocked_level
	]


# Two taps needed: the first arms the button, the second (within 3 s) resets.
func _on_reset_pressed() -> void:
	if not reset_armed:
		reset_armed = true
		%Reset.text = "TAP AGAIN TO RESET"
		%Reset.theme_type_variation = &"Button" # Pink = warning.
		reset_tween = create_tween()
		reset_tween.tween_interval(RESET_CONFIRM_TIME)
		reset_tween.tween_callback(disarm_reset)
		return

	reset_tween.kill()
	GameState.reset_progress()
	update_progress_info()
	disarm_reset()
	%Reset.text = "PROGRESS RESET"
	%Reset.disabled = true # Nothing left to reset.


func disarm_reset() -> void:
	reset_armed = false
	%Reset.text = "RESET PROGRESS"
	%Reset.theme_type_variation = &"PaleButton"
