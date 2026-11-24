# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name MapEditorValidator
extends RefCounted


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
