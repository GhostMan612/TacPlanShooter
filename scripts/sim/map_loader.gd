# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name MapLoader
extends RefCounted


const GROUND_FLOOR := 0


static func load_from_json(path: String) -> GreyboxMap:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return GreyboxMap.new()
	var text := f.get_as_text()
	f.close()
	return load_from_string(text)


static func load_from_string(text: String) -> GreyboxMap:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return GreyboxMap.new()
	var d: Dictionary = parsed
	return from_data(d)


static func from_data(d: Dictionary) -> GreyboxMap:
	if d.has("solids") or d.has("w"):
		return GreyboxMap.from_dict(d)
	var m := GreyboxMap.new()
	m.width_cells = int(d.get("width_cells", 16))
	m.height_cells = int(d.get("height_cells", 12))
	for w in d.get("walls", []):
		if not on_floor(w, GROUND_FLOOR):
			continue
		var mat := StringName(String(w.get("material", "CONCRETE")))
		for c in wall_cells(_snap(w["a"]), _snap(w["b"]), m.width_cells, m.height_cells):
			m.solid_cells[c] = true
			m.wall_materials[c] = mat
	for door in d.get("doors", []):
		if not on_floor(door, GROUND_FLOOR):
			continue
		var c := _snap(door["cell"])
		var state := StringName(String(door.get("state", "CLOSED_UNLOCKED")))
		m.door_cells[c] = true
		m.door_open[c] = state == &"OPEN" or state == &"BREACHED_DESTROYED"
		m.door_states[c] = state
	m.insertion_zones = floor_filter(d.get("insertion_zones", []), GROUND_FLOOR)
	m.extraction_zones = floor_filter(d.get("extraction_zones", []), GROUND_FLOOR)
	m.defender_zones = floor_filter(d.get("defender_zones", []), GROUND_FLOOR)
	m.chokepoints = floor_filter(d.get("chokepoints", []), GROUND_FLOOR)
	m.objectives = floor_filter(d.get("objectives", []), GROUND_FLOOR)
	m.ai_spawns = floor_filter(d.get("ai_spawns", []), GROUND_FLOOR)
	m.hostage_spawns = floor_filter(d.get("hostage_spawns", []), GROUND_FLOOR)
	m.jammer_nodes = floor_filter(d.get("jammer_nodes", []), GROUND_FLOOR)
	return m


static func on_floor(entry: Variant, floor_index: int) -> bool:
	if typeof(entry) != TYPE_DICTIONARY:
		return floor_index == GROUND_FLOOR
	var e: Dictionary = entry
	return int(e.get("floor", GROUND_FLOOR)) == floor_index


static func floor_filter(entries: Array, floor_index: int) -> Array:
	var out := []
	for e in entries:
		if on_floor(e, floor_index):
			out.append(e)
	return out


static func wall_cells(a: Vector2i, b: Vector2i, w: int, h: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var p := a
	var steps := maxi(dx, -dy)
	for i in range(steps + 1):
		if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h:
			out.append(p)
		if p == b:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			p.x += sx
		if e2 <= dx:
			err += dx
			p.y += sy
	return out


static func _snap(p: Array) -> Vector2i:
	return Vector2i(int(float(p[0])), int(float(p[1])))
