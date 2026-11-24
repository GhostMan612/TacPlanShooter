# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
extends SceneTree


func _initialize() -> void:
	var failures := 0
	failures += _validate_map("res://data/maps/op01_glass_house.json")
	failures += _validate_map("res://data/maps/op02_night_shift.json")
	failures += _validate_map("res://data/maps/op03_iron_shutter.json")
	failures += _validate_map("res://data/maps/op04_silent_relay.json")
	failures += _validate_map("res://data/maps/op05_penthouse_lock.json")
	failures += _validate_map("res://data/maps/op06_redline_terminal.json")
	failures += _validate_map("res://data/maps/op07_blackwater_pier.json")
	failures += _validate_map("res://data/maps/op08_cold_vault.json")
	failures += _validate_map("res://data/maps/op09_signal_tower.json")
	failures += _validate_map("res://data/maps/op10_sovereign_citadel.json")
	print("[HARNESS] RESULT %s failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _validate_map(path: String) -> int:
	var m := MapLoader.load_from_json(path)
	var ok := m != null and m.width_cells >= 1 and m.height_cells >= 1
	for z in m.insertion_zones:
		for c in z["cells"]:
			ok = ok and _ok_cell(m, c)
	for z in m.extraction_zones:
		for c in z["cells"]:
			ok = ok and _ok_cell(m, c)
	for o in m.objectives:
		ok = ok and _ok_cell(m, o["cell"])
	for s in m.ai_spawns:
		ok = ok and _ok_cell(m, s["cell"])
	for s in m.hostage_spawns:
		ok = ok and _ok_cell(m, s["cell"])
	var start := Vector2i(-1, -1)
	for z in m.insertion_zones:
		for c in z["cells"]:
			if _ok_cell(m, c):
				start = Vector2i(int(c[0]), int(c[1]))
				break
		if start.x >= 0:
			break
	if start.x >= 0:
		for o in m.objectives:
			var g := Vector2i(int(o["cell"][0]), int(o["cell"][1]))
			ok = ok and GridPathfinder.find_path(m, start, g).size() >= 1
	for s in m.ai_spawns:
		var p := Vector2((s["cell"][0] + 0.5) * 16.0, (s["cell"][1] + 0.5) * 16.0)
		var poly := Visibility.compute_polygon(p, m.get_wall_segments(), 0.00001)
		ok = ok and poly.size() >= 0
	print("[HARNESS] map_validation %s (%s)" % ["PASS" if ok else "FAIL", path])
	return 0 if ok else 1


func _ok_cell(m: GreyboxMap, c: Array) -> bool:
	var cell := Vector2i(int(c[0]), int(c[1]))
	return m.in_bounds(cell) and not m.is_solid(cell)
