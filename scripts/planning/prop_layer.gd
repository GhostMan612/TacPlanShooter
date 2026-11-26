# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name PropLayer
extends Node2D


enum Kind { CRATE, TERMINAL, DESK, BARREL }


var map: GreyboxMap = null
var entries: Array = []


func setup(m: GreyboxMap) -> void:
	map = m
	y_sort_enabled = true
	entries = []
	if map == null:
		return
	for y in range(1, map.height_cells - 1):
		for x in range(1, map.width_cells - 1):
			var c := Vector2i(x, y)
			if map.is_solid(c) or map.door_cells.has(c):
				continue
			if _is_zone(c) or _near_spawn(c) or _near_wall(c):
				continue
			var h := (x * 73856093) ^ (y * 19349663)
			if (h & 7) != 0:
				continue
			entries.append({"cell": c, "kind": (h >> 4) & 3, "y": y})
	entries.sort_custom(_sort_by_y)
	queue_redraw()


func _sort_by_y(a: Dictionary, b: Dictionary) -> bool:
	return int(a["y"]) < int(b["y"])


func _is_zone(c: Vector2i) -> bool:
	for z in map.insertion_zones:
		for e in z.get("cells", []):
			if Vector2i(int(e[0]), int(e[1])) == c:
				return true
	for z in map.extraction_zones:
		for e in z.get("cells", []):
			if Vector2i(int(e[0]), int(e[1])) == c:
				return true
	for o in map.objectives:
		if Vector2i(int(o["cell"][0]), int(o["cell"][1])) == c:
			return true
	return false


func _near_spawn(c: Vector2i) -> bool:
	for o in map.ai_spawns:
		if Vector2(Vector2i(int(o["cell"][0]), int(o["cell"][1])) - c).length() <= 1.0:
			return true
	return false


func _near_wall(c: Vector2i) -> bool:
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if map.solid_cells.has(c + d):
			return true
	return false


func _draw() -> void:
	var s := float(SimConstants.GRID_CELL_SIZE_PX)
	for e in entries:
		var c: Vector2i = e["cell"]
		var r := GridUtil.cell_rect_px(c)
		var p := r.position
		draw_rect(Rect2(p.x + 2.0, p.y + s - 4.0, s - 4.0, 4.0), Color(0, 0, 0, 0.35), true)
		match int(e["kind"]):
			Kind.CRATE:
				draw_rect(Rect2(p.x + 2.0, p.y + 3.0, s - 4.0, s - 6.0), Color(0.30, 0.35, 0.42), true)
				draw_rect(Rect2(p.x + 2.0, p.y + 3.0, s - 4.0, s - 6.0), Color(0.55, 0.62, 0.70), false, 1.0)
				draw_line(p + Vector2(3.0, 4.0), p + Vector2(s - 3.0, s - 5.0), Color(0.45, 0.52, 0.6, 0.6), 1.0)
			Kind.TERMINAL:
				draw_rect(Rect2(p.x + 3.0, p.y + 1.0, s - 6.0, s - 5.0), Color(0.14, 0.22, 0.30), true)
				draw_rect(Rect2(p.x + 4.0, p.y + 2.0, s - 8.0, 5.0), Color(0.15, 0.95, 0.95, 0.9), true)
				draw_rect(Rect2(p.x + 4.0, p.y + 9.0, s - 8.0, 2.0), Color(0.10, 0.55, 0.65, 0.7), true)
			Kind.DESK:
				draw_rect(Rect2(p.x + 1.0, p.y + 4.0, s - 2.0, s - 8.0), Color(0.36, 0.27, 0.18), true)
				draw_rect(Rect2(p.x + 1.0, p.y + 4.0, s - 2.0, 2.0), Color(0.55, 0.42, 0.28), true)
			Kind.BARREL:
				draw_circle(p + Vector2(s * 0.5, s * 0.55), s * 0.33, Color(0.42, 0.28, 0.18))
				draw_arc(p + Vector2(s * 0.5, s * 0.55), s * 0.33, 0.0, TAU, 12, Color(0.75, 0.52, 0.30), 1.0)
