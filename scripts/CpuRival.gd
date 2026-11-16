class_name CpuRival
extends RefCounted # A helper object; it doesn't need a scene node.

var score: int = 0 # CPU points for this attempt.
var accuracy: float = 0.55 # Chance of catching each good food.
var rng := RandomNumberGenerator.new() # CPU's own random generator.
var lives: int = 3 # CPU starts each attempt with three lives.
# Power foods (see Level.gd):
var incoming: int = 0 # Rotten foods the player tossed that the CPU still has to dodge.
var shield: bool = false # Blocks the player's next attack.
var double_until: float = -INF # Song time when the CPU's double points end.
var ink_until: float = -INF # Song time when the player's INK stops bothering the CPU.
const INK_PENALTY: float = 0.3 # Inked: 30% less likely to catch.

func setup(level: int) -> void:
	score = 0 # Start every attempt fresh.
	lives = 3 # Reset CPU health for a new attempt.
	incoming = 0
	shield = false
	accuracy = clampf(0.55 + (level - 1) * 0.08, 0.55, 0.87)
	rng.randomize() # Vary its performance between attempts.


# time = current song time (for INK and x2). Returns true if the CPU caught
# it (used for power foods).
func judge_good_note(time: float) -> bool:
	if lives <= 0:
		return false # An eliminated CPU cannot earn more points.
	var chance: float = accuracy - (INK_PENALTY if time < ink_until else 0.0)
	if rng.randf() >= chance:
		return false # Simulate a missed catch: no points.

	# Successful catches use the player's same point values.
	var points: int = 100 if rng.randf() < 0.75 else 50 # Simulated PERFECT / GOOD.
	if time < double_until:
		points *= 2
	score += points
	return true

func judge_bad_note() -> void:
	if lives <= 0:
		return # Already eliminated.

	if rng.randf() >= accuracy:
		lives -= 1 # Failed to avoid rotten food.
