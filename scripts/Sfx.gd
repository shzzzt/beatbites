class_name Sfx
extends Node
# Plays short sound effects. Level.gd adds one of these and the HUD borrows it.
# It keeps a few AudioStreamPlayers and takes turns using them, so several
# sounds can overlap (e.g. three tossed rotten foods landing one after another).
# The sounds are made by tools/make_sfx.py. They play on the Master bus, so the
# SOUND ON/OFF setting and the volume slider affect them too.

const SOUNDS: Dictionary = {
	"throw": preload("res://assets/audio/sfx/throw.wav"),
	"splat": preload("res://assets/audio/sfx/splat.wav"),
	"incoming": preload("res://assets/audio/sfx/incoming.wav"),
	"land": preload("res://assets/audio/sfx/land.wav"),
	"ink": preload("res://assets/audio/sfx/ink.wav"),
	"shield": preload("res://assets/audio/sfx/shield.wav"),
	"blocked": preload("res://assets/audio/sfx/blocked.wav"),
	"double": preload("res://assets/audio/sfx/double.wav"),
	"heart": preload("res://assets/audio/sfx/heart.wav"),
	"bonk": preload("res://assets/audio/sfx/bonk.wav"),
}
const PLAYER_COUNT: int = 8 # Up to 8 sounds at the same time.

var players: Array[AudioStreamPlayer] = []
var next_player: int = 0


func _ready() -> void:
	for i in PLAYER_COUNT:
		var player := AudioStreamPlayer.new()
		add_child(player)
		players.append(player)


# volume_db: 0 = normal, -6 = about half as loud (used for the CPU's powers).
# A tiny random pitch change keeps repeated sounds from feeling robotic.
func play(sound: String, volume_db: float = 0.0) -> void:
	var player: AudioStreamPlayer = players[next_player]
	next_player = (next_player + 1) % players.size()
	player.stream = SOUNDS[sound]
	player.volume_db = volume_db
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()
