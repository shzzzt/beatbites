class_name CpuRival
extends RefCounted # A helper object; it doesn't need a scene node.

var score: int = 0 # CPU points for this attempt.
var accuracy: float = 0.55 # Chance of catching each good food.
var rng := RandomNumberGenerator.new() # CPU's own random generator.


func setup(level: int) -> void:
	score = 0 # Start every attempt fresh.
	accuracy = clampf(0.55 + (level - 1) * 0.08, 0.55, 0.87)
	rng.randomize() # Vary its performance between attempts.


func judge_good_note() -> void:
	if rng.randf() >= accuracy:
		return # Simulate a missed catch: no points.

	# Successful catches use the player's same point values.
	if rng.randf() < 0.75:
		score += 100 # Simulated PERFECT.
	else:
		score += 50 # Simulated GOOD.
