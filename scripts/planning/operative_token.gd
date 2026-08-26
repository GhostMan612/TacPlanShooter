# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name OperativeToken
extends Node2D

const BASE_COLOR := Color(0.55, 0.62, 0.7)
const SELECTED_COLOR := Color(0.25, 0.85, 1.0)
const OUTLINE_ALPHA := 0.45
const RADIUS := 11.0

var op_id := -1
var selected := false


func _init(p_id := -1) -> void:
	op_id = p_id


func set_selected(v: bool) -> void:
	selected = v
	queue_redraw()


func _draw() -> void:
	var col := SELECTED_COLOR if selected else BASE_COLOR
	draw_circle(Vector2.ZERO, RADIUS, col)
	draw_arc(Vector2.ZERO, RADIUS + 3.0, 0.0, TAU, 40, Color(col.r, col.g, col.b, OUTLINE_ALPHA), 1.5)
	draw_string(ThemeDB.fallback_font, Vector2(-4.0, 4.5), str(op_id), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.02, 0.04, 0.06))
