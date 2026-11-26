# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name MapRenderer
extends Node2D


const FLOOR_A := Color(0x18, 0x22, 0x2E)
const FLOOR_B := Color(0x1D, 0x28, 0x36)
const BEVEL_HI := Color(0.36, 0.45, 0.56, 0.55)
const BEVEL_LO := Color(0.03, 0.05, 0.09, 0.7)
const GRID_COLOR := Color(0.45, 0.62, 0.78, 0.08)
const WALL_CAP := Color(0x0E, 0x15, 0x1F)
const WALL_RIM := Color(0x4B, 0x5E, 0x75)
const WALL_FACE := Color(0x26, 0x33, 0x44)
const WALL_SEAM := Color(0.10, 0.15, 0.22, 0.8)
const WALL_VENT := Color(0.35, 0.45, 0.55, 0.35)
const SHADOW := Color(0, 0, 0, 0.42)
const DOOR_FRAME := Color(0.42, 0.49, 0.58)
const DOOR_LEAF := Color(0.20, 0.28, 0.38)
const LED_RED := Color(0.95, 0.22, 0.18)
const LED_GREEN := Color(0.18, 0.85, 0.38)
const IN_COLOR := Color(0.20, 0.85, 0.42, 0.26)
const EX_COLOR := Color(0.95, 0.72, 0.10, 0.26)
const OBJ_COLOR := Color(0.95, 0.25, 0.22, 0.26)
const INK := Color(0.86, 0.92, 0.98, 0.92)


var map: GreyboxMap = null
var palette: Dictionary = {}
var hd_tilemap: TileMap = null
var show_overlay := true


func setup(m: GreyboxMap) -> void:
	map = m
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func apply_palette(pal: Dictionary) -> void:
	palette = pal
	queue_redraw()


func enable_hd_tiles() -> bool:
	return false


func _cell_color(cell: Vector2i) -> Color:
	var h := (cell.x * 73856093) ^ (cell.y * 19349663)
	var t := (h & 3)
	return FLOOR_A if t < 2 else FLOOR_B


func _is_wall(cell: Vector2i) -> bool:
	return map != null and map.solid_cells.has(cell) and not map.door_cells.has(cell)


func _solid(cell: Vector2i) -> bool:
	return map != null and map.is_solid(cell)


func _draw() -> void:
	if map == null:
		return
	var s := float(SimConstants.GRID_CELL_SIZE_PX)
	var w := int(map.width_cells)
	var h := int(map.height_cells)
	var total := Rect2(Vector2.ZERO, Vector2(w, h) * s)
	draw_rect(total, FLOOR_A, true)
	for y in range(h):
		for x in range(w):
			_draw_plate(Vector2i(x, y), s)
	if show_overlay and SimClock.phase == SimClock.Phase.PLANNING:
		_draw_grid(w, h, s)
	for y in range(h):
		for x in range(w):
			var c := Vector2i(x, y)
			if _is_wall(c):
				_draw_wall(c, s)
	for c in map.door_cells.keys():
		_draw_door(Vector2i(c), s)
	_draw_zones(s)
	for c in map.solid_cells.keys():
		var cell := Vector2i(c)
		for nb in [Vector2i(cell.x - 1, cell.y), Vector2i(cell.x + 1, cell.y), Vector2i(cell.x, cell.y - 1), Vector2i(cell.x, cell.y + 1)]:
			if map.door_cells.has(nb):
				_draw_hazard(nb, s, cell)
	if show_overlay and SimClock.phase == SimClock.Phase.PLANNING:
		_draw_headers(w, h, s)


func _draw_plate(c: Vector2i, s: float) -> void:
	var r := GridUtil.cell_rect_px(c)
	draw_rect(r, _cell_color(c), true)
	draw_line(r.position, Vector2(r.end.x, r.position.y), BEVEL_HI, 1.0)
	draw_line(r.position, Vector2(r.position.x, r.end.y), BEVEL_HI, 1.0)
	draw_line(Vector2(r.position.x, r.end.y), r.end, BEVEL_LO, 1.0)
	draw_line(Vector2(r.end.x, r.position.y), r.end, BEVEL_LO, 1.0)
	var h := (c.x * 73856093) ^ (c.y * 19349663)
	if (h & 15) == 0:
		draw_rect(r.grow(-4.0), Color(0.30, 0.38, 0.46, 0.35), false, 1.0)


func _draw_grid(w: int, h: int, s: float) -> void:
	for x in range(w + 1):
		draw_line(Vector2(x * s, 0), Vector2(x * s, h * s), GRID_COLOR, 1.0)
	for y in range(h + 1):
		draw_line(Vector2(0, y * s), Vector2(w * s, y * s), GRID_COLOR, 1.0)


func _draw_wall(c: Vector2i, s: float) -> void:
	var r := GridUtil.cell_rect_px(c)
	var below := Vector2i(c.x, c.y + 1)
	if map.in_bounds(below) and not _solid(below):
		var face := Rect2(r.position.x, r.end.y - 3.0, s, s * 0.85)
		draw_rect(Rect2(r.position.x, r.end.y, s, s * 0.65), SHADOW, true)
		draw_rect(face, WALL_FACE, true)
		draw_rect(Rect2(face.position.x, face.position.y, s, 2.0), Color(0.32, 0.43, 0.55, 0.6), true)
		draw_rect(Rect2(face.position.x, face.end.y - 3.0, s, 3.0), Color(0.05, 0.08, 0.12), true)
		for k in range(1, 4):
			draw_line(Vector2(face.position.x, face.position.y + k * s * 0.2), Vector2(face.end.x, face.position.y + k * s * 0.2), WALL_SEAM, 1.0)
		var h := (c.x * 73856093) ^ (c.y * 19349663)
		if (h & 7) == 0:
			draw_rect(Rect2(face.position.x + 3.0, face.position.y + s * 0.28, s - 6.0, 3.0), WALL_VENT, true)
	draw_rect(r, WALL_CAP, true)
	for nb in [Vector2i(c.x - 1, c.y), Vector2i(c.x + 1, c.y), Vector2i(c.x, c.y - 1), Vector2i(c.x, c.y + 1)]:
		if _solid(nb):
			continue
		var a := Vector2.ZERO
		var b := Vector2.ZERO
		if nb.x < c.x:
			a = r.position
			b = Vector2(r.position.x, r.end.y)
		elif nb.x > c.x:
			a = Vector2(r.end.x, r.position.y)
			b = r.end
		elif nb.y < c.y:
			a = r.position
			b = Vector2(r.end.x, r.position.y)
		else:
			a = Vector2(r.position.x, r.end.y)
			b = r.end
		draw_line(a, b, WALL_RIM, 2.0)


func _draw_door(c: Vector2i, s: float) -> void:
	var r := GridUtil.cell_rect_px(c).grow(1.0)
	draw_rect(r, SHADOW, true)
	draw_rect(r, DOOR_FRAME, false, 2.0)
	var state := map.door_state(c)
	var open := state == &"OPEN" or state == &"BREACHED_DESTROYED"
	var leaf := r.grow(-4.0)
	if not open:
		draw_rect(leaf, DOOR_LEAF, true)
		draw_line(leaf.position, leaf.end, Color(0.55, 0.62, 0.7, 0.5), 1.0)
	draw_rect(Rect2(r.position.x + 3.0, r.position.y - 3.0, s - 6.0, 3.0), LED_GREEN if open else (LED_RED if state == &"LOCKED" or state == &"BARRICADED" else Color(0.95, 0.65, 0.12)), true)
	if state == &"BREACHED_DESTROYED":
		for i in range(4):
			var a := float(i) * TAU / 4.0
			draw_line(r.get_center(), r.get_center() + Vector2(cos(a), sin(a)) * s * 0.45, Color(1.0, 0.7, 0.2, 0.8), 1.2)


func _stripe_zone(cells: Array, col: Color, label: String, s: float) -> void:
	for entry in cells:
		var c := Vector2i(int(entry[0]), int(entry[1]))
		var r := GridUtil.cell_rect_px(c)
		draw_rect(r, col, true)
		var i := 0
		while i < int(s * 2.0):
			var ox := float(i) * 8.0 - s
			draw_line(r.position + Vector2(ox, 0), r.position + Vector2(ox + s, s), Color(col.r, col.g, col.b, 0.45), 1.0)
			i += 1
		draw_string(ThemeDB.fallback_font, r.position + Vector2(2.0, s - 3.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)


func _draw_zones(s: float) -> void:
	for z in map.insertion_zones:
		_stripe_zone(z.get("cells", []), IN_COLOR, "IN", s)
	for z in map.extraction_zones:
		_stripe_zone(z.get("cells", []), EX_COLOR, "EX", s)
	for o in map.objectives:
		_stripe_zone([o.get("cell", [])], OBJ_COLOR, "OBJ", s)


func _draw_hazard(cell: Vector2i, s: float, wall: Vector2i) -> void:
	var r := GridUtil.cell_rect_px(cell)
	var d := cell - wall
	if d.x != 0:
		draw_rect(Rect2(r.position.x + (0.0 if d.x > 0 else s - 3.0), r.position.y, 3.0, s), Color(0.86, 0.68, 0.12, 0.35), true)
	else:
		draw_rect(Rect2(r.position.x, r.position.y + (0.0 if d.y > 0 else s - 3.0), s, 3.0), Color(0.86, 0.68, 0.12, 0.35), true)


func _draw_headers(w: int, h: int, s: float) -> void:
	for i in range(w):
		draw_string(ThemeDB.fallback_font, Vector2(i * s + 2.0, -4.0), col_letter(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK)
	for i in range(h):
		draw_string(ThemeDB.fallback_font, Vector2(-20.0, i * s + 11.0), str(i + 1).pad_zeros(2), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK)


static func col_letter(x: int) -> String:
	var letters := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	if x < 0:
		return "?"
	if x < 26:
		return letters.substr(x, 1)
	return letters.substr((x / 26) - 1, 1) + letters.substr(x % 26, 1)
