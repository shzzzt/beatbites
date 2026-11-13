@tool
class_name DashedLine
extends Control
# A horizontal pixel dashed line across this Control's width, at its top edge.
# @tool makes it draw in the editor too, so you can see it while placing it.

@export var color: Color = Color("#FF9ACD")
@export var thickness: float = 8.0
@export var dash: float = 24.0 # Length of each dash.
@export var gap: float = 16.0 # Space between dashes.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var x: float = 0.0
	while x < size.x:
		var length: float = minf(dash, size.x - x) # Don't draw past the end.
		draw_rect(Rect2(x, 0.0, length, thickness), color)
		x += dash + gap
