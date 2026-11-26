# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name MapRenderer
extends Node2D


const FLOOR_COLOR := Color(0.016, 0.031, 0.055)
const SOLID_COLOR := Color(0.075, 0.11, 0.16)
const GRID_COLOR := Color(0.09, 0.2, 0.32, 0.22)
const MAJOR_COLOR := Color(0.16, 0.4, 0.62)
const DOOR_CLOSED_COLOR := Color(0.85, 0.52, 0.13)
const DOOR_OPEN_COLOR := Color(0.16, 0.7, 0.33)
const ZONE_GREEN := Color(0.2, 0.7, 0.2, 0.8)
const ZONE_AMBER := Color(0.8, 0.7, 0.1, 0.6)
const ZONE_RED := Color(0.8, 0.2, 0.2, 0.9)
const HOSTAGE_COLOR := Color(0.23, 0.51, 0.96)
const HD_TILESET_PATH := "res://addons/godot4-asset-vault/tacplanshooter_hd/tilesets/spacegrunts_25d_tileset.tres"
const HD_FLOOR_PATH := "res://assets/textures/concrete_seamless_256.png"
const HD_WALL_PATH := "res://assets/textures/spacegrunts_25d_tileset.png"


var map: GreyboxMap = null
var palette := {}
var hd_tilemap: TileMap = null
var hd_floor: Texture2D = null
var hd_wall: Texture2D = null


func setup(m: GreyboxMap) -> void:
	map = m
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func apply_palette(pal: Dictionary) -> void:
	palette = pal
	queue_redraw()


func enable_hd_tiles() -> bool:
	if hd_floor == null and ResourceLoader.exists(HD_FLOOR_PATH):
		hd_floor = ResourceLoader.load(HD_FLOOR_PATH, "Texture2D") as Texture2D
	if hd_wall == null and ResourceLoader.exists(HD_WALL_PATH):
		hd_wall = ResourceLoader.load(HD_WALL_PATH, "Texture2D") as Texture2D
	if hd_tilemap != null:
		return true
	if not ResourceLoader.exists(HD_TILESET_PATH):
		return false
	var ts := ResourceLoader.load(HD_TILESET_PATH, "TileSet") as TileSet
	if ts == null:
		return false
	hd_tilemap = TileMap.new()
	hd_tilemap.tile_set = ts
	add_child(hd_tilemap)
	return true


func _color(key: String, fallback: Color) -> Color:
	if palette.has(key):
		return palette[key]
	return fallback


func _draw() -> void:
	if map == null:
		return
	var c_floor := _color("bg", FLOOR_COLOR)
	var c_major := _color("accent", MAJOR_COLOR)
	var c_grid := _color("grid", GRID_COLOR)
	var c_wall := _color("wall", SOLID_COLOR)
	var c_door_closed := _color("door_closed", DOOR_CLOSED_COLOR)
	var c_door_open := _color("door_open", DOOR_OPEN_COLOR)
	var c_ink := _color("ink", Color(0.9, 0.92, 0.95))
	var s := float(SimConstants.GRID_CELL_SIZE_PX)
	var total := Rect2(Vector2.ZERO, Vector2(map.width_cells, map.height_cells) * s)
	draw_rect(total, c_floor, true)
	if hd_floor != null:
		draw_texture_rect(hd_floor, total, true, Color(1.0, 1.0, 1.0, 0.65))
	elif hd_tilemap == null:
		draw_rect(total, c_floor, true)
	var x := 0.0
	while x <= total.size.x + 0.01:
		var major := int(x / s) % 5 == 0
		draw_line(Vector2(x, 0), Vector2(x, total.size.y), c_major if major else c_grid, 1.5 if major else 0.5)
		x += s
	var y := 0.0
	while y <= total.size.y + 0.01:
		var major := int(y / s) % 5 == 0
		draw_line(Vector2(0, y), Vector2(total.size.x, y), c_major if major else c_grid, 1.5 if major else 0.5)
		y += s
	var c_red := _color("red", ZONE_RED)
	for c in map.solid_cells.keys():
		var cell := Vector2i(c)
		if map.door_cells.has(cell):
			continue
		var rect := GridUtil.cell_rect_px(cell)
		if hd_wall != null and rect.size.x > 0:
			draw_texture_rect_region(hd_wall, rect, Rect2(0, 0, 16, 16), Color(1.0, 1.0, 1.0, 0.85))
			continue
		var mat := StringName(map.wall_materials.get(cell, &"CONCRETE"))
		if mat == &"DRY_WALL":
			draw_rect(rect, c_wall.lerp(c_floor, 0.4), true)
			draw_rect(rect.grow(-4.0), c_wall, true)
		elif mat == &"ARMORED":
			draw_rect(rect, c_wall, true)
			draw_rect(rect.grow(-2.5), c_major, false, 1.0)
		else:
			draw_rect(rect, c_wall, true)
	for c in map.door_cells.keys():
		var cell := Vector2i(c)
		var rect := GridUtil.cell_rect_px(cell)
		var state := map.door_state(cell)
		draw_rect(rect, c_floor, true)
		if state == &"OPEN" or state == &"BREACHED_DESTROYED":
			draw_rect(rect.grow(-3.0), c_door_open, false, 1.0)
			continue
		draw_rect(rect.grow(-2.0), c_door_closed, true)
		if state == &"LOCKED":
			draw_rect(Rect2(rect.get_center() - Vector2(3.0, 2.0), Vector2(6.0, 5.0)), c_floor, true)
			draw_arc(rect.get_center() - Vector2(0.0, 2.0), 2.0, PI, TAU, 8, c_floor, 1.0)
		elif state == &"BARRICADED":
			draw_line(rect.position + Vector2(2, 2), rect.end - Vector2(2, 2), c_red, 1.5)
			draw_line(Vector2(rect.end.x - 2, rect.position.y + 2), Vector2(rect.position.x + 2, rect.end.y - 2), c_red, 1.5)
	for z in map.insertion_zones:
		for c in z.get("cells", []):
			draw_rect(GridUtil.cell_rect_px(Vector2i(int(c[0]), int(c[1]))), ZONE_GREEN)
	for z in map.extraction_zones:
		for c in z.get("cells", []):
			draw_rect(GridUtil.cell_rect_px(Vector2i(int(c[0]), int(c[1]))), ZONE_AMBER)
	for o in map.objectives:
		draw_rect(GridUtil.cell_rect_px(Vector2i(int(o["cell"][0]), int(o["cell"][1]))), ZONE_RED)
	for h in map.hostage_spawns:
		var hrect := GridUtil.cell_rect_px(MapEditorValidator.cell_of(h)).grow(-2.0)
		draw_rect(hrect, HOSTAGE_COLOR, false, 1.5)
		draw_string(ThemeDB.fallback_font, hrect.position + Vector2(0.5, hrect.size.y - 3.0), "HST", HORIZONTAL_ALIGNMENT_LEFT, -1, 5, HOSTAGE_COLOR)
	for s_link in map.stairs_from_floor(map.floor_index):
		var sc: Array = s_link.get("from_cell", [])
		if sc.size() >= 2:
			var srect := GridUtil.cell_rect_px(Vector2i(int(sc[0]), int(sc[1]))).grow(-1.5)
			draw_rect(srect, Color(0.2, 0.9, 0.95, 0.35), true)
			draw_rect(srect, Color(0.25, 0.95, 1.0, 0.95), false, 1.5)
			draw_string(ThemeDB.fallback_font, srect.position + Vector2(1.0, 9.0), "F%d" % (int(s_link.get("to_floor", 0)) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.9, 1.0, 1.0))
	var font := ThemeDB.fallback_font
	for i in range(map.width_cells):
		draw_string(font, Vector2(i * s + 3.0, -6.0), col_letter(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c_ink)
	for i in range(map.height_cells):
		draw_string(font, Vector2(-22.0, i * s + 12.0), str(i + 1).pad_zeros(2), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c_ink)


static func col_letter(x: int) -> String:
	var letters := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	if x < 0:
		return "?"
	if x < 26:
		return letters.substr(x, 1)
	return letters.substr((x / 26) - 1, 1) + letters.substr(x % 26, 1)
