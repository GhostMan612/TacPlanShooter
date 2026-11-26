# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
extends SceneTree


const EXPECTED_DIMS := {
	"op01_glass_house": [32, 24],
}

const EXPECTED_SOLIDS := {
	"op01_glass_house": 250,
	"op02_night_shift": 68,
	"op03_iron_shutter": 73,
	"op04_silent_relay": 64,
	"op05_penthouse_lock": 66,
	"op06_redline_terminal": 72,
	"op07_blackwater_pier": 68,
	"op08_cold_vault": 68,
	"op09_signal_tower": 52,
	"op10_sovereign_citadel": 68,
}

var _initialized := false


func _init() -> void:
	call_deferred("_ensure_initialized")


func _ensure_initialized() -> void:
	if not _initialized:
		_initialize()


func _initialize() -> void:
	if _initialized:
		return
	_initialized = true
	var failures := 0
	for map_id in EXPECTED_SOLIDS.keys():
		failures += _validate_map(String(map_id), int(EXPECTED_SOLIDS[map_id]))
	failures += _test_door_states()
	failures += _test_rasterizer()
	print("[HARNESS] RESULT %s failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _validate_map(map_id: String, expected_solids: int) -> int:
	var path := "res://data/maps/%s.json" % map_id
	var m := MapLoader.load_from_json(path)
	var dims: Array = EXPECTED_DIMS.get(map_id, [16, 12])
	var ok := m.width_cells == int(dims[0]) and m.height_cells == int(dims[1])
	ok = ok and m.solid_cells.size() == expected_solids
	var flags := MapEditorValidator.validate(m, true)
	ok = ok and flags.is_empty()
	for lst in [m.insertion_zones, m.extraction_zones, m.objectives, m.ai_spawns, m.hostage_spawns, m.jammer_nodes]:
		for e in lst:
			ok = ok and MapLoader.on_floor(e, MapLoader.GROUND_FLOOR)
	var segs := m.get_wall_segments()
	var interior := 0
	for s in segs:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		ok = ok and a.x >= 0.0 and a.y >= 0.0 and b.x <= float(dims[0]) and b.y <= float(dims[1])
		if not (a.x == b.x and (a.x == 0.0 or a.x == float(dims[0]))) and not (a.y == b.y and (a.y == 0.0 or a.y == float(dims[1]))):
			interior += 1
	ok = ok and interior > 0
	var first := "" if flags.is_empty() else "%s at %s" % [String(flags[0]["reason"]), str(flags[0]["cell"])]
	print("[HARNESS] map_validation %s (%s solids=%d segs=%d %s)" % ["PASS" if ok else "FAIL", map_id, m.solid_cells.size(), segs.size(), first])
	return 0 if ok else 1


func _test_door_states() -> int:
	var m3 := MapLoader.load_from_json("res://data/maps/op03_iron_shutter.json")
	var ok := m3.door_state(Vector2i(2, 2)) == &"LOCKED" and m3.is_solid(Vector2i(2, 2))
	ok = ok and m3.door_state(Vector2i(10, 8)) == &"CLOSED_UNLOCKED" and m3.is_solid(Vector2i(10, 8))
	var m1 := MapLoader.load_from_json("res://data/maps/op01_glass_house.json")
	ok = ok and m1.door_state(Vector2i(5, 2)) == &"OPEN" and not m1.is_solid(Vector2i(5, 2))
	ok = ok and m1.wall_materials.get(Vector2i(5, 4), &"") == &"DRY_WALL"
	ok = ok and m1.wall_materials.get(Vector2i(0, 4), &"") == &"CONCRETE"
	var back := GreyboxMap.from_dict(m3.to_dict())
	ok = ok and back.door_state(Vector2i(2, 2)) == &"LOCKED" and back.solid_cells.size() == m3.solid_cells.size()
	print("[HARNESS] map_door_states %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_rasterizer() -> int:
	var row := MapLoader.wall_cells(Vector2i(0, 0), Vector2i(16, 0), 16, 12)
	var ok := row.size() == 16 and row[0] == Vector2i(0, 0) and row[15] == Vector2i(15, 0)
	var rev := MapLoader.wall_cells(Vector2i(10, 8), Vector2i(10, 2), 16, 12)
	ok = ok and rev.size() == 7 and rev.has(Vector2i(10, 8)) and rev.has(Vector2i(10, 2))
	var one := MapLoader.wall_cells(Vector2i(4, 4), Vector2i(4, 4), 16, 12)
	ok = ok and one.size() == 1
	var diag := MapLoader.wall_cells(Vector2i(1, 1), Vector2i(4, 4), 16, 12)
	ok = ok and diag.size() == 4 and diag.has(Vector2i(2, 2))
	print("[HARNESS] map_rasterizer %s (row=%d rev=%d diag=%d)" % ["PASS" if ok else "FAIL", row.size(), rev.size(), diag.size()])
	return 0 if ok else 1
