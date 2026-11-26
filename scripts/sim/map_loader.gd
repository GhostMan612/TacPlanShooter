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
	var m := _build_floor(d, GROUND_FLOOR)
	var count := maxi(1, int(d.get("floors", 1)))
	m.floor_count = count
	var slices: Array[GreyboxMap] = [m]
	for fl in range(1, count):
		var fm := _build_floor(d, fl)
		fm.floor_count = count
		slices.append(fm)
	var links := _normalize_stairs(d.get("stair_links", []), slices)
	m.stair_links = links
	if count > 1 or not links.is_empty():
		m.floor_slices.clear()
		for fl in range(slices.size()):
			slices[fl].stair_links = links.duplicate(true)
			m.floor_slices.append(slices[fl].to_slice_dict())
	return m


static func _build_floor(d: Dictionary, floor_idx: int) -> GreyboxMap:
	var m := GreyboxMap.new()
	m.floor_index = floor_idx
	m.tileset_theme = StringName(String(d.get("tileset_theme", "tactical_compound")))
	m.width_cells = int(d.get("width_cells", 16))
	m.height_cells = int(d.get("height_cells", 12))
	if floor_idx > 0:
		for x in range(m.width_cells):
			m.solid_cells[Vector2i(x, 0)] = true
			m.solid_cells[Vector2i(x, m.height_cells - 1)] = true
		for y in range(m.height_cells):
			m.solid_cells[Vector2i(0, y)] = true
			m.solid_cells[Vector2i(m.width_cells - 1, y)] = true
	for w in d.get("walls", []):
		if not on_floor(w, floor_idx):
			continue
		var mat := StringName(String(w.get("material", "CONCRETE")))
		for c in wall_cells(_snap(w["a"]), _snap(w["b"]), m.width_cells, m.height_cells):
			m.solid_cells[c] = true
			m.wall_materials[c] = mat
	for door in d.get("doors", []):
		if not on_floor(door, floor_idx):
			continue
		var c := _snap(door["cell"])
		var state := StringName(String(door.get("state", "CLOSED_UNLOCKED")))
		m.door_cells[c] = true
		m.door_open[c] = state == &"OPEN" or state == &"BREACHED_DESTROYED"
		m.door_states[c] = state
	m.insertion_zones = floor_filter(d.get("insertion_zones", []), floor_idx)
	m.extraction_zones = floor_filter(d.get("extraction_zones", []), floor_idx)
	m.defender_zones = floor_filter(d.get("defender_zones", []), floor_idx)
	m.chokepoints = floor_filter(d.get("chokepoints", []), floor_idx)
	m.objectives = floor_filter(d.get("objectives", []), floor_idx)
	m.ai_spawns = floor_filter(d.get("ai_spawns", []), floor_idx)
	m.hostage_spawns = floor_filter(d.get("hostage_spawns", []), floor_idx)
	m.jammer_nodes = floor_filter(d.get("jammer_nodes", []), floor_idx)
	if floor_idx > 0:
		for lst in [m.objectives, m.ai_spawns, m.hostage_spawns]:
			for e in lst:
				if e is Dictionary and e.has("cell"):
					_carve_walkable(m, _snap(e["cell"]))
		for zlst in [m.insertion_zones, m.extraction_zones, m.defender_zones]:
			for z in zlst:
				for raw_c in z.get("cells", []):
					_carve_walkable(m, _snap(raw_c))
		for s in d.get("stair_links", []):
			if int(s.get("from_floor", -1)) == floor_idx and s.has("from_cell"):
				_carve_walkable(m, _snap(s["from_cell"]))
			if int(s.get("to_floor", -1)) == floor_idx and s.has("to_cell"):
				_carve_walkable(m, _snap(s["to_cell"]))
	return m


static func _carve_walkable(m: GreyboxMap, c: Vector2i) -> void:
	if m.in_bounds(c) and not m.door_cells.has(c):
		m.solid_cells.erase(c)


static func _normalize_stairs(raw_links: Array, slices: Array[GreyboxMap]) -> Array:
	var out := []
	var seen := {}
	for raw in raw_links:
		if not (raw is Dictionary):
			continue
		var ff := int(raw.get("from_floor", 0))
		var tf := int(raw.get("to_floor", 0))
		if ff < 0 or ff >= slices.size() or tf < 0 or tf >= slices.size() or ff == tf:
			continue
		var fc := _snap_walkable(slices[ff], _snap(raw.get("from_cell", [0, 0])))
		var tc := _snap_walkable(slices[tf], _snap(raw.get("to_cell", [0, 0])))
		var fwd_key := "%d:%d,%d->%d:%d,%d" % [ff, fc.x, fc.y, tf, tc.x, tc.y]
		if not seen.has(fwd_key):
			seen[fwd_key] = true
			out.append({"from_floor": ff, "from_cell": [fc.x, fc.y], "to_floor": tf, "to_cell": [tc.x, tc.y]})
	for idx in range(out.size()):
		var link: Dictionary = out[idx]
		var ff := int(link["to_floor"])
		var tf := int(link["from_floor"])
		var fc: Array = link["to_cell"]
		var tc: Array = link["from_cell"]
		var rev_key := "%d:%d,%d->%d:%d,%d" % [ff, int(fc[0]), int(fc[1]), tf, int(tc[0]), int(tc[1])]
		if not seen.has(rev_key):
			seen[rev_key] = true
			out.append({"from_floor": ff, "from_cell": [int(fc[0]), int(fc[1])], "to_floor": tf, "to_cell": [int(tc[0]), int(tc[1])]})
	return out


static func _snap_walkable(m: GreyboxMap, c: Vector2i) -> Vector2i:
	var clamped := Vector2i(clampi(c.x, 0, m.width_cells - 1), clampi(c.y, 0, m.height_cells - 1))
	if not m.is_solid(clamped) or m.door_cells.has(clamped):
		return clamped
	for d in GridPathfinder.ORTHO:
		var nb: Vector2i = clamped + d
		if m.in_bounds(nb) and (not m.is_solid(nb) or m.door_cells.has(nb)):
			return nb
	return clamped


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
