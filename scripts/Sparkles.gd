class_name Sparkles
extends Control
# Pastel pixel sparkles behind a menu screen. Add a full-screen Control with
# this script as the first child of any UI scene.

const SIZE: float = 12.0 # Sparkle size in pixels.
const LILAC := Color("#E3D4FF")
const PINK := Color("#FFC9E3")
const BLUE := Color("#C7E6FF")

# Positions from the mockup (390 × 844), stored as fractions of the screen
# so they spread out the same way on any phone size.
const DOTS: Array = [
	[40.0 / 390, 60.0 / 844, LILAC], [320.0 / 390, 90.0 / 844, PINK],
	[120.0 / 390, 150.0 / 844, BLUE], [250.0 / 390, 40.0 / 844, LILAC],
	[60.0 / 390, 300.0 / 844, PINK], [340.0 / 390, 260.0 / 844, BLUE],
	[200.0 / 390, 220.0 / 844, LILAC], [30.0 / 390, 520.0 / 844, BLUE],
	[360.0 / 390, 480.0 / 844, PINK], [150.0 / 390, 400.0 / 844, LILAC],
	[280.0 / 390, 700.0 / 844, BLUE], [90.0 / 390, 780.0 / 844, PINK],
	[330.0 / 390, 600.0 / 844, LILAC],
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE # Never block taps.
	resized.connect(queue_redraw) # Redraw if the screen size changes.


func _draw() -> void:
	for dot in DOTS:
		# Round to whole pixels so the squares stay sharp.
		var pos := Vector2(roundf(dot[0] * size.x), roundf(dot[1] * size.y))
		draw_rect(Rect2(pos, Vector2(SIZE, SIZE)), dot[2])
