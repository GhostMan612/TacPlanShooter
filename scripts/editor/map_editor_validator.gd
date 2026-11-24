# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name MapEditorValidator
extends RefCounted


static func has_import_shape(data: Dictionary) -> bool:
	var compact := data.has("w") or data.has("solids")
	var width_key := "w" if compact else "width_cells"
	var height_key := "h" if compact else "height_cells"
	var walls_key := "solids" if compact else "walls"
	var doors_key := "door_cells" if compact else "doors"
	if not (data.has(width_key) or data.has(height_key) or data.has(walls_key) or data.has(doors_key)):
		return false
	if not _positive_dimension(data.get(width_key, 16)) or not _positive_dimension(data.get(height_key, 12)):
		return false
	if compact:
		if not _cell_rows(data.get("solids", [])) or not _cell_rows(data.get("door_cells", [])):
			return false
		if not _cell_rows(data.get("door_open", []), TYPE_BOOL):
			return false
		if not _cell_rows(data.get("door_states", []), TYPE_STRING) or not _cell_rows(data.get("wall_materials", []), TYPE_STRING):
			return false
	else:
		var walls: Variant = data.get("walls", [])
		var doors: Variant = data.get("doors", [])
		if not (walls is Array and doors is Array):
			return false
		for wall in walls:
			if not wall is Dictionary or not _cell_row(wall.get("a")) or not _cell_row(wall.get("b")):
				return false
			if not _number(wall.get("floor", 0)) or not wall.get("material", "") is String:
				return false
		for door in doors:
			if not door is Dictionary or not _cell_row(door.get("cell")):
				return false
			if not _number(door.get("floor", 0)) or not door.get("state", "") is String:
				return false
	for key in ["insertion_zones", "extraction_zones", "defender_zones"]:
		var zones: Variant = data.get(key, [])
		if not zones is Array:
			return false
		for zone in zones:
			if not zone is Dictionary or not _cell_rows(zone.get("cells")):
				return false
			if not compact and not _number(zone.get("floor", 0)):
				return false
	for key in ["objectives", "ai_spawns", "hostage_spawns", "jammer_nodes"]:
		var entries: Variant = data.get(key, [])
		if not entries is Array:
			return false
		for entry in entries:
			if entry is Dictionary:
				if not _cell_row(entry.get("cell")) or (not compact and not _number(entry.get("floor", 0))):
					return false
			elif key != "jammer_nodes" or not _cell_row(entry):
				return false
	return true


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _positive_dimension(value: Variant) -> bool:
	return _number(value) and float(value) >= 1.0 and float(value) <= 2147483647.0 and floor(float(value)) == float(value)


static func _cell_row(row: Variant) -> bool:
	return row is Array and row.size() >= 2 and _number(row[0]) and _number(row[1])


static func _cell_rows(rows: Variant, value_type: int = TYPE_NIL) -> bool:
	if not rows is Array:
		return false
	for row in rows:
		if not _cell_row(row):
			return false
		if value_type != TYPE_NIL and (row.size() < 3 or typeof(row[2]) != value_type):
			return false
	return true


static func validate(m: GreyboxMap, require_insertion: bool = false) -> Array:
	var out := []
	if m == null:
		return out
	if m.width_cells < 1 or m.height_cells < 1:
		out.append({"cell": [0, 0], "reason": &"map is empty"})
		return out
	_check_cells(m, m.solid_cells.keys(), out, &"solid cell out of bounds")
	_check_cells(m, m.door_cells.keys(), out, &"door cell out of bounds")
	var targets: Array[Vector2i] = []
	for z in m.insertion_zones:
		_check_zone(m, z, out, &"insertion zone")
	for z in m.extraction_zones:
		_check_zone(m, z, out, &"extraction zone")
		for c in _zone_cells(z):
			targets.append(c)
	for z in m.defender_zones:
		_check_zone(m, z, out, &"defender zone")
	for o in m.objectives:
		var oc := cell_of(o)
		_check_point(m, oc, out, &"objective")
		targets.append(oc)
	for s in m.ai_spawns:
		_check_point(m, cell_of(s), out, &"ai spawn")
	for s in m.hostage_spawns:
		_check_point(m, cell_of(s), out, &"hostage spawn")
	for j in m.jammer_nodes:
		_check_point(m, cell_of(j), out, &"jammer")
	var start := insertion_start(m)
	if start.x < 0:
		if require_insertion:
			out.append({"cell": [0, 0], "reason": &"no walkable insertion cell"})
		return out
	for t in targets:
		if t == start or not m.in_bounds(t) or blocked(m, t):
			continue
		if GridPathfinder.find_path(m, start, t).is_empty():
			out.append({"cell": [t.x, t.y], "reason": &"unreachable from insertion"})
	var poly := Visibility.compute_polygon(Vector2(start) + Vector2(0.5, 0.5), m.get_wall_segments(), SimConstants.LOS_VERTEX_EPSILON_RAD)
	if poly.size() < 3:
		out.append({"cell": [start.x, start.y], "reason": &"insertion has no visibility polygon"})
	return out


static func cell_of(v: Variant) -> Vector2i:
	if typeof(v) == TYPE_DICTIONARY:
		var d: Dictionary = v
		return cell_of(d.get("cell", [-1, -1]))
	if typeof(v) == TYPE_ARRAY:
		var a: Array = v
		if a.size() >= 2:
			return Vector2i(int(a[0]), int(a[1]))
	if typeof(v) == TYPE_VECTOR2I:
		return v
	return Vector2i(-1, -1)


static func blocked(m: GreyboxMap, c: Vector2i) -> bool:
	return m.solid_cells.has(c) and not m.door_cells.has(c)


static func insertion_start(m: GreyboxMap) -> Vector2i:
	for z in m.insertion_zones:
		for c in _zone_cells(z):
			if m.in_bounds(c) and not blocked(m, c):
				return c
	return Vector2i(-1, -1)


static func _zone_cells(z: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if typeof(z) != TYPE_DICTIONARY:
		return out
	var d: Dictionary = z
	for c in d.get("cells", []):
		out.append(cell_of(c))
	return out


static func _check_point(m: GreyboxMap, c: Vector2i, out: Array, what: StringName) -> void:
	if not m.in_bounds(c):
		out.append({"cell": [c.x, c.y], "reason": StringName(String(what) + " cell out of bounds")})
	elif blocked(m, c):
		out.append({"cell": [c.x, c.y], "reason": StringName(String(what) + " inside a wall")})


static func _check_cells(m: GreyboxMap, cells: Array, out: Array, why: StringName) -> void:
	for c in cells:
		var cell: Vector2i = c
		if not m.in_bounds(cell):
			out.append({"cell": [cell.x, cell.y], "reason": why})


static func _check_zone(m: GreyboxMap, z: Variant, out: Array, why: StringName) -> void:
	for cell in _zone_cells(z):
		_check_point(m, cell, out, why)
