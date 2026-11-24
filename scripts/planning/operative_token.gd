# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name OperativeToken
extends Node2D


const BASE_COLOR := Color(0.55, 0.62, 0.7)
const SELECTED_COLOR := Color(0.25, 0.85, 1.0)
const OUTLINE_ALPHA := 0.45
const RADIUS := 6.5


var op_id := -1
var selected := false
var has_lkp := false


func _init(p_id := -1) -> void:
	op_id = p_id


func set_selected(v: bool) -> void:
	selected = v
	queue_redraw()


func set_lkp(v: bool) -> void:
	has_lkp = v
	queue_redraw()


func _draw() -> void:
	var col := SELECTED_COLOR if selected else BASE_COLOR
	draw_circle(Vector2.ZERO, RADIUS, col)
	draw_arc(Vector2.ZERO, RADIUS + 1.5, 0.0, TAU, 32, Color(col.r, col.g, col.b, OUTLINE_ALPHA), 1.0)
	if has_lkp:
		draw_circle(Vector2.ZERO, RADIUS + 5.5, Color(0.5, 0.55, 0.65, 0.45))
