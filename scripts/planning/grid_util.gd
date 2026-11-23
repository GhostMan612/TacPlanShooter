# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name GridUtil
extends Object


static func px_to_cell(p: Vector2) -> Vector2i:
	var s := float(SimConstants.GRID_CELL_SIZE_PX)
	return Vector2i(int(floor(p.x / s)), int(floor(p.y / s)))


static func cell_center_px(c: Vector2i) -> Vector2:
	var s := float(SimConstants.GRID_CELL_SIZE_PX)
	return Vector2((float(c.x) + 0.5) * s, (float(c.y) + 0.5) * s)


static func cell_rect_px(c: Vector2i) -> Rect2:
	return Rect2(Vector2(c) * float(SimConstants.GRID_CELL_SIZE_PX), Vector2.ONE * float(SimConstants.GRID_CELL_SIZE_PX))


static func px_points_to_cell_waypoints(points: PackedVector2Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p in points:
		out.append(px_to_cell(p))
	return out


static func collapse_consecutive_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in cells:
		if out.size() == 0 or out[out.size() - 1] != c:
			out.append(c)
	return out


static func cell_of(p: Vector2) -> Vector2i:
	# Sim-layer position → containing cell (cell-unit space; D-017).
	return Vector2i(int(floor(p.x)), int(floor(p.y)))
