@tool
class_name DashedLine
extends Control
# Pixel dashed lines. @tool makes it draw in the editor too.
#   HORIZONTAL: one line along the top edge (title / gameplay catch line)
#   VERTICAL:   one line down the left edge (gameplay lane dividers)
#   BOX:        a dashed border around the whole rect (locked meal cards)

enum Mode { HORIZONTAL, VERTICAL, BOX }

@export var mode: Mode = Mode.HORIZONTAL:
	set(value):
		mode = value
		queue_redraw() # Update the editor preview right away.
@export var color: Color = Color("#FF9ACD")
@export var thickness: float = 8.0
@export var dash: float = 24.0 # Length of each dash.
@export var gap: float = 16.0 # Space between dashes.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	match mode:
		Mode.HORIZONTAL:
			_dash_h(0.0, size.x)
		Mode.VERTICAL:
			_dash_v(0.0, size.y)
		Mode.BOX:
			_dash_h(0.0, size.x)
			_dash_h(size.y - thickness, size.x)
			_dash_v(0.0, size.y)
			_dash_v(size.x - thickness, size.y)


# Dashes from x = 0 to `length` at height y.
func _dash_h(y: float, length: float) -> void:
	var x: float = 0.0
	while x < length:
		draw_rect(Rect2(x, y, minf(dash, length - x), thickness), color)
		x += dash + gap


# Dashes from y = 0 to `length` at position x.
func _dash_v(x: float, length: float) -> void:
	var y: float = 0.0
	while y < length:
		draw_rect(Rect2(x, y, thickness, minf(dash, length - y)), color)
		y += dash + gap
