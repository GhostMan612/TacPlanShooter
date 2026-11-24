# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name MapEditorValidator
extends RefCounted


static func validate(m: GreyboxMap) -> Array:
	var out := []
	if m == null:
		return out
	if m.width_cells < 1 or m.height_cells < 1:
		out.append({"cell": [0, 0], "reason": &"map is empty"})
	_check_cells(m, m.solid_cells.keys(), out, &"solid cell out of bounds")
	_check_cells(m, m.door_cells.keys(), out, &"door cell out of bounds")
	for z in m.insertion_zones:
		_check_zone(m, z, out, &"insertion zone")
	for z in m.extraction_zones:
		_check_zone(m, z, out, &"extraction zone")
	for z in m.defender_zones:
		_check_zone(m, z, out, &"defender zone")
	for o in m.objectives:
		if not m.in_bounds(Vector2i(int(o["cell"][0]), int(o["cell"][1]))):
			out.append({"cell": [int(o["cell"][0]), int(o["cell"][1])], "reason": &"objective cell out of bounds"})
	for s in m.ai_spawns:
		if not m.in_bounds(Vector2i(int(s["cell"][0]), int(s["cell"][1]))):
			out.append({"cell": [int(s["cell"][0]), int(s["cell"][1])], "reason": &"ai spawn cell out of bounds"})
	for s in m.hostage_spawns:
		if not m.in_bounds(Vector2i(int(s["cell"][0]), int(s["cell"][1]))):
			out.append({"cell": [int(s["cell"][0]), int(s["cell"][1])], "reason": &"hostage spawn cell out of bounds"})
	for j in m.jammer_nodes:
		if not m.in_bounds(Vector2i(int(j[0]), int(j[1]))):
			out.append({"cell": [int(j[0]), int(j[1])], "reason": &"jammer cell out of bounds"})
	return out


static func _check_cells(m: GreyboxMap, cells: Array, out: Array, why: StringName) -> void:
	for c in cells:
		if not m.in_bounds(c):
			out.append({"cell": [int(c.x), int(c.y)], "reason": why})


static func _check_zone(m: GreyboxMap, z: Dictionary, out: Array, why: StringName) -> void:
	for c in z.get("cells", []):
		var cell := Vector2i(int(c[0]), int(c[1]))
		if not m.in_bounds(cell):
			out.append({"cell": [cell.x, cell.y], "reason": why})
