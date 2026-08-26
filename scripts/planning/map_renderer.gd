# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name MapRenderer
extends Node2D

const FLOOR_COLOR := Color(0.016, 0.031, 0.055)
const SOLID_COLOR := Color(0.075, 0.11, 0.16)
const GRID_COLOR := Color(0.09, 0.2, 0.32, 0.22)
const DOOR_CLOSED_COLOR := Color(0.85, 0.52, 0.13)
const DOOR_OPEN_COLOR := Color(0.16, 0.7, 0.33)

var map: GreyboxMap = null


func setup(m: GreyboxMap) -> void:
	map = m
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if map == null:
		return
	var s := float(SimConstants.GRID_CELL_SIZE_PX)
	var total := Rect2(Vector2.ZERO, Vector2(map.width_cells, map.height_cells) * s)
	draw_rect(total, FLOOR_COLOR, true)
	var x := 0.0
	while x <= total.size.x + 0.01:
		draw_line(Vector2(x, 0), Vector2(x, total.size.y), GRID_COLOR, 1.0)
		x += s
	var y := 0.0
	while y <= total.size.y + 0.01:
		draw_line(Vector2(0, y), Vector2(total.size.x, y), GRID_COLOR, 1.0)
		y += s
	for c in map.solid_cells.keys():
		draw_rect(GridUtil.cell_rect_px(Vector2i(c)), SOLID_COLOR, true)
	for c in map.door_open.keys():
		var is_open := bool(map.door_open[c])
		draw_rect(GridUtil.cell_rect_px(Vector2i(c)).grow(-2.0), DOOR_OPEN_COLOR if is_open else DOOR_CLOSED_COLOR, true)
