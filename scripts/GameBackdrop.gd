class_name GameBackdrop
extends CanvasLayer
# Gameplay background (drawn behind everything, layer -1): sparkles, dashed
# lines between the lanes, and the catch line. Level.gd sets lane_count
# before adding it, and the lane lines are made here to match.

var lane_count: int = 3

const LINE_COLOR := Color("#E3D4FF")
const LINE_TOP: float = 300.0
const LINE_BOTTOM: float = 1280.0


func _ready() -> void:
	var lane_width: float = 720.0 / lane_count # Game is designed 720 wide.
	for i in range(1, lane_count):
		var line := DashedLine.new()
		line.mode = DashedLine.Mode.VERTICAL
		line.color = LINE_COLOR
		line.dash = 16.0
		line.gap = 12.0
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.position = Vector2(roundf(lane_width * i) - 4.0, LINE_TOP)
		line.size = Vector2(8.0, LINE_BOTTOM - LINE_TOP)
		add_child(line)
	move_child($CatchLine, -1) # Keep the catch line on top of the lane lines.
