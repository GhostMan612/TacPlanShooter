# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name PipLoupe
extends Control


const LOUPE_PX := 168.0
const VIEW_SCALE := 3.0
const CELL_RADIUS := 2

var _map: GreyboxMap = null
var _world_pos := Vector2.ZERO
var _route := PackedVector2Array()
var _route_color := Color(0.25, 0.85, 1.0, 0.9)


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(LOUPE_PX, LOUPE_PX)
	custom_minimum_size = size


func show_at(screen_pos: Vector2, world_pos: Vector2, vp_size: Vector2, p_map: GreyboxMap, p_route: PackedVector2Array, p_color: Color) -> void:
	_world_pos = world_pos
	_map = p_map
	_route = p_route
	_route_color = p_color
	var x := clampf(screen_pos.x - LOUPE_PX * 0.5, 12.0, maxf(12.0, vp_size.x - LOUPE_PX - 12.0))
	var y := clampf(screen_pos.y - LOUPE_PX - 72.0, 12.0, maxf(12.0, vp_size.y - LOUPE_PX - 12.0))
	position = Vector2(x, y)
	visible = true
	queue_redraw()


func hide_loupe() -> void:
	visible = false


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(LOUPE_PX, LOUPE_PX))
	draw_rect(rect, Color(0.02, 0.05, 0.09, 0.94), true)
	var center := Vector2(LOUPE_PX * 0.5, LOUPE_PX * 0.5)
	var cell_px := float(SimConstants.GRID_CELL_SIZE_PX)
	var base_cell := GridUtil.px_to_cell(_world_pos)
	if _map != null:
		for dy in range(-CELL_RADIUS - 1, CELL_RADIUS + 2):
			for dx in range(-CELL_RADIUS - 1, CELL_RADIUS + 2):
				var c := Vector2i(base_cell.x + dx, base_cell.y + dy)
				if not _map.in_bounds(c):
					continue
				var top_left := center + (Vector2(c) * cell_px - _world_pos) * VIEW_SCALE
				var csize := Vector2(cell_px * VIEW_SCALE, cell_px * VIEW_SCALE)
				var crect := Rect2(top_left, csize).intersection(rect)
				if crect.size.x <= 0.0 or crect.size.y <= 0.0:
					continue
				if _map.door_cells.has(c):
					var dc := Color(0.16, 0.7, 0.33, 0.85) if bool(_map.door_open.get(c, false)) else Color(0.85, 0.52, 0.13, 0.9)
					draw_rect(crect, dc, true)
				elif _map.solid_cells.has(c):
					draw_rect(crect, Color(0.12, 0.18, 0.26, 0.95), true)
				draw_rect(crect, Color(0.18, 0.38, 0.55, 0.35), false, 1.0)
	if _route.size() >= 2:
		var mapped := PackedVector2Array()
		for p in _route:
			mapped.append(center + (p - _world_pos) * VIEW_SCALE)
		draw_polyline(mapped, _route_color, 2.5, false)
	draw_line(Vector2(center.x - 10.0, center.y), Vector2(center.x + 10.0, center.y), Color(1.0, 0.9, 0.3, 0.95), 1.5)
	draw_line(Vector2(center.x, center.y - 10.0), Vector2(center.x, center.y + 10.0), Color(1.0, 0.9, 0.3, 0.95), 1.5)
	draw_rect(rect, Color(0.28, 0.75, 0.95, 0.9), false, 2.0)
	var label := "%s%02d" % [MapRenderer.col_letter(base_cell.x), base_cell.y + 1]
	draw_string(ThemeDB.fallback_font, Vector2(8.0, 18.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.95, 1.0))
