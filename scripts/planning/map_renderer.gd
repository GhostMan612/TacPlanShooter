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
const COORD_COLOR := Color(0.5, 0.75, 1.0)
const ZONE_GREEN := Color(0.2, 0.7, 0.2, 0.8)
const ZONE_AMBER := Color(0.8, 0.7, 0.1, 0.6)
const ZONE_RED := Color(0.8, 0.2, 0.2, 0.9)


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
	for x in range(map.width_cells):
		draw_line(Vector2(x * s, 0), Vector2(x * s, total.size.y), COORD_COLOR, 0.5)
	for y in range(map.height_cells):
		draw_line(Vector2(0, y * s), Vector2(total.size.x, y * s), COORD_COLOR, 0.5)
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
	for c in map.door_cells.keys():
		var is_open := bool(map.door_open.get(c, false))
		draw_rect(GridUtil.cell_rect_px(Vector2i(c)).grow(-2.0), DOOR_OPEN_COLOR if is_open else DOOR_CLOSED_COLOR, true)
	for z in map.insertion_zones:
		for c in z["cells"]:
			draw_rect(GridUtil.cell_rect_px(Vector2i(int(c[0]), int(c[1]))), ZONE_GREEN)
	for z in map.extraction_zones:
		for c in z["cells"]:
			draw_rect(GridUtil.cell_rect_px(Vector2i(int(c[0]), int(c[1]))), ZONE_AMBER)
	for o in map.objectives:
		draw_rect(GridUtil.cell_rect_px(Vector2i(int(o["cell"][0]), int(o["cell"][1]))), ZONE_RED)


func _col_letter(x: int) -> String:
	var arr := [&"A", &"B", &"C", &"D", &"E", &"F", &"G", &"H", &"I", &"J", &"K", &"L", &"M", &"N", &"O", &"P", &"Q", &"R", &"S", &"T", &"U", &"V", &"W", &"X", &"Y", &"Z"]
	return String(arr[x % 26])
