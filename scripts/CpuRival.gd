class_name CpuRival
extends RefCounted # A helper object; it doesn't need a scene node.

var score: int = 0 # CPU points for this attempt.
var accuracy: float = 0.55 # Chance of catching each good food.
var rng := RandomNumberGenerator.new() # CPU's own random generator.
var lives: int = 3 # CPU starts each attempt with three lives.
var incoming: int = 0 # Rotten foods the player threw that haven't hit yet.

func setup(level: int) -> void:
	score = 0 # Start every attempt fresh.
	lives = 3 # Reset CPU health for a new attempt.
	incoming = 0
	accuracy = clampf(0.55 + (level - 1) * 0.08, 0.55, 0.87)
	rng.randomize() # Vary its performance between attempts.


# Returns true if the CPU caught it (used for power foods).
func judge_good_note() -> bool:
	if lives <= 0:
		return false # An eliminated CPU cannot earn more points.
	if rng.randf() >= accuracy:
		return false # Simulate a missed catch: no points.

	# Successful catches use the player's same point values.
	if rng.randf() < 0.75:
		score += 100 # Simulated PERFECT.
	else:
		score += 50 # Simulated GOOD.
	return true

func judge_bad_note() -> void:
	if lives <= 0:
		return # Already eliminated.

	if rng.randf() >= accuracy:
		lives -= 1 # Failed to avoid rotten food.
