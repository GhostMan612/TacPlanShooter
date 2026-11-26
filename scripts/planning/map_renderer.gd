# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name MapRenderer
extends Node2D


var FLOOR_A := Color.html("#18222E")
var FLOOR_B := Color.html("#1D2836")
const BEVEL_HI := Color(0.36, 0.45, 0.56, 0.55)
const BEVEL_LO := Color(0.03, 0.05, 0.09, 0.7)
const GRID_COLOR := Color(0.06, 0.14, 0.20, 0.14)
var WALL_CAP := Color.html("#0E151F")
var WALL_RIM := Color.html("#4B5E75")
var WALL_FACE := Color.html("#263344")
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
var hd_atlas: Texture2D = null
var hd_normal: Texture2D = null
var hd_modulate := Color(1, 1, 1, 1)
var show_overlay := true
var theme: TilesetTheme = null
var grid_color: Color = GRID_COLOR
var floor_tint: Color = Color(1, 1, 1, 1)
var theme_light: Color = Color(1, 1, 1, 1)


func setup(m: GreyboxMap) -> void:
	map = m
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func apply_palette(pal: Dictionary) -> void:
	palette = pal
	var accent: Color = pal.get("accent", Color.WHITE)
	var ink: Color = pal.get("ink", Color.WHITE)
	hd_modulate = Color.WHITE.lerp(accent.lerp(ink, 0.35), 0.18)
	hd_modulate.a = 1.0
	queue_redraw()


func apply_theme(t: TilesetTheme) -> void:
	theme = t
	if t == null:
		grid_color = GRID_COLOR
		floor_tint = Color(1, 1, 1, 1)
		theme_light = Color(1, 1, 1, 1)
	else:
		grid_color = t.color(&"grid_color", GRID_COLOR)
		floor_tint = t.color(&"floor_tint", Color(1, 1, 1, 1))
		theme_light = t.color(&"light_color", Color(1, 1, 1, 1))
	queue_redraw()


func _color(key: String, fallback: Color) -> Color:
	if palette.has(key):
		return palette[key]
	return fallback


func _tinted(c: Color) -> Color:
	return Color(c.r * floor_tint.r, c.g * floor_tint.g, c.b * floor_tint.b, c.a)


func enable_hd_tiles() -> bool:
	if hd_atlas != null:
		return true
	var p := "res://assets/textures/spacegrunts_25d_tileset.png"
	if not ResourceLoader.exists(p):
		return false
	hd_atlas = ResourceLoader.load(p, "Texture2D") as Texture2D
	if hd_atlas == null:
		return false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var np := "res://assets/textures/spacegrunts_25d_tileset_n.png"
	if ResourceLoader.exists(np):
		hd_normal = ResourceLoader.load(np, "Texture2D") as Texture2D
	queue_redraw()
	return true


func _cell_color(cell: Vector2i) -> Color:
	var h := (cell.x * 73856093) ^ (cell.y * 19349663)
	var t := (h & 3)
	return FLOOR_A if t < 2 else FLOOR_B


func _is_wall(cell: Vector2i) -> bool:
	return map != null and map.solid_cells.has(cell) and not map.door_cells.has(cell)


func _solid(cell: Vector2i) -> bool:
	return map != null and map.is_solid(cell)


func _is_planning_phase() -> bool:
	if not is_inside_tree():
		return true
	var sc: Node = get_tree().root.get_node_or_null("SimClock")
	if sc == null:
		return true
	return int(sc.get("phase")) == 0


func _draw() -> void:
	if map == null:
		return
	var s := float(SimConstants.GRID_CELL_SIZE_PX)
	var w := int(map.width_cells)
	var h := int(map.height_cells)
	var total := Rect2(Vector2.ZERO, Vector2(w, h) * s)
	draw_rect(total, _tinted(FLOOR_A), true)
	for y in range(h):
		for x in range(w):
			_draw_plate(Vector2i(x, y), s)
	if show_overlay and _is_planning_phase():
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
	if show_overlay and _is_planning_phase():
		_draw_headers(w, h, s)


func _draw_plate(c: Vector2i, s: float) -> void:
	var r := GridUtil.cell_rect_px(c)
	draw_rect(r, _tinted(_cell_color(c)), true)
	if hd_atlas != null:
		var h := (c.x * 73856093) ^ (c.y * 19349663)
		var src := Rect2(float((h & 1) * 16), 16.0, 16.0, 16.0)
		var tint := Color(0.94, 0.96, 1.0, 1.0) if (h & 2) == 0 else Color(0.86, 0.90, 0.95, 1.0)
		draw_texture_rect_region(hd_atlas, r, src, hd_modulate * tint)
	draw_line(r.position, Vector2(r.end.x, r.position.y), BEVEL_HI, 1.0)
	draw_line(r.position, Vector2(r.position.x, r.end.y), BEVEL_HI, 1.0)
	draw_line(Vector2(r.position.x, r.end.y), r.end, BEVEL_LO, 1.0)
	draw_line(Vector2(r.end.x, r.position.y), r.end, BEVEL_LO, 1.0)
	var h := (c.x * 73856093) ^ (c.y * 19349663)
	if (h & 15) == 0:
		draw_rect(r.grow(-4.0), Color(0.30, 0.38, 0.46, 0.35), false, 1.0)


func _draw_grid(w: int, h: int, s: float) -> void:
	for x in range(w + 1):
		draw_line(Vector2(x * s, 0), Vector2(x * s, h * s), grid_color, 1.0)
	for y in range(h + 1):
		draw_line(Vector2(0, y * s), Vector2(w * s, y * s), grid_color, 1.0)


func _draw_wall(c: Vector2i, s: float) -> void:
	var r := GridUtil.cell_rect_px(c)
	var below := Vector2i(c.x, c.y + 1)
	if map.in_bounds(below) and not _solid(below):
		var face := Rect2(r.position.x, r.end.y - 3.0, s, s * 0.85)
		draw_rect(Rect2(r.position.x, r.end.y, s, s * 0.65), SHADOW, true)
		if hd_atlas != null:
			draw_texture_rect_region(hd_atlas, face, Rect2(16, 0, 16, 16), hd_modulate)
		else:
			draw_rect(face, WALL_FACE, true)
		draw_rect(Rect2(face.position.x, face.position.y, s, 2.0), Color(0.32, 0.43, 0.55, 0.6), true)
		draw_rect(Rect2(face.position.x, face.end.y - 3.0, s, 3.0), Color(0.05, 0.08, 0.12), true)
		for k in range(1, 4):
			draw_line(Vector2(face.position.x, face.position.y + k * s * 0.2), Vector2(face.end.x, face.position.y + k * s * 0.2), WALL_SEAM, 1.0)
		var h := (c.x * 73856093) ^ (c.y * 19349663)
		if (h & 7) == 0:
			draw_rect(Rect2(face.position.x + 3.0, face.position.y + s * 0.28, s - 6.0, 3.0), WALL_VENT, true)
	draw_rect(r, WALL_CAP, true)
	if hd_atlas != null:
		draw_texture_rect_region(hd_atlas, r, Rect2(0, 0, 16, 16), hd_modulate)
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
	if hd_atlas != null:
		draw_texture_rect_region(hd_atlas, r, Rect2(32, 0, 16, 16), hd_modulate)
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
		if not map.in_bounds(c):
			continue
		var r := GridUtil.cell_rect_px(c)
		draw_rect(r, col, true)
		var k := 0
		while k < 4:
			var ox := float(k) * s * 0.25
			draw_line(r.position + Vector2(ox, 2.0), r.position + Vector2(minf(ox + 8.0, s), s - 2.0), Color(col.r, col.g, col.b, 0.45), 1.0)
			k += 1
		draw_string(ThemeDB.fallback_font, r.position + Vector2(0.0, s - 2.0), label, HORIZONTAL_ALIGNMENT_CENTER, s, 8, INK)


func _draw_zones(s: float) -> void:
	for z in map.insertion_zones:
		for c in z.get("cells", []):
			var cell := Vector2i(int(c[0]), int(c[1]))
			if map.in_bounds(cell):
				_stripe_zone([c], IN_COLOR, "IN", s)
	for z in map.extraction_zones:
		for c in z.get("cells", []):
			var cell := Vector2i(int(c[0]), int(c[1]))
			if map.in_bounds(cell):
				_stripe_zone([c], EX_COLOR, "EX", s)
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


