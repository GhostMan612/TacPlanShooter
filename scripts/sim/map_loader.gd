# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name MapLoader
extends RefCounted


static func load_from_json(path: String) -> GreyboxMap:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return GreyboxMap.new()
	var text := f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(text)
	if data == null:
		return GreyboxMap.new()
	return from_data(data)


static func from_data(d: Dictionary) -> GreyboxMap:
	var m := GreyboxMap.new()
	m.width_cells = int(d.get("width_cells", 16))
	m.height_cells = int(d.get("height_cells", 12))
	for w in d.get("walls", []):
		m.solid_cells[_snap(w["a"])] = true
	for door in d.get("doors", []):
		var c := _snap(door["cell"])
		m.door_cells[c] = true
		m.door_open[c] = String(door.get("state", "CLOSED_UNLOCKED")) == &"OPEN"
	m.insertion_zones = d.get("insertion_zones", [])
	m.extraction_zones = d.get("extraction_zones", [])
	m.defender_zones = d.get("defender_zones", [])
	m.objectives = d.get("objectives", [])
	m.ai_spawns = d.get("ai_spawns", [])
	m.hostage_spawns = d.get("hostage_spawns", [])
	m.jammer_nodes = d.get("jammer_nodes", [])
	return m


static func _snap(p: Array) -> Vector2i:
	return Vector2i(int(float(p[0])), int(float(p[1])))
