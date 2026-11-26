# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := 0
	var expected := [
		&"tactical_compound", &"industrial_warehouse", &"moonbase_lab",
		&"bank_vault", &"ancestral_crypt",
	]
	var ids := ThemeRegistry.ids()
	if ids.size() != expected.size():
		failures += 1
		print("[THEME] FAIL registry ids=%d expected=%d" % [ids.size(), expected.size()])
	for id in expected:
		var t := ThemeRegistry.for_id(id)
		var ok := t != null and t.is_valid()
		ok = ok and t.floor_tiles.size() == 4 and t.wall_face_variants.size() == 4
		ok = ok and t.doors.size() == 5 and t.props_atlas != null
		ok = ok and t.door_texture(&"BREACHED_DESTROYED") != null
		if not ok:
			failures += 1
		print("[THEME] theme %s %s" % [String(id), "PASS" if ok else "FAIL"])
	var unknown := ThemeRegistry.for_id(&"not_a_theme")
	if unknown == null or unknown.theme_id != &"tactical_compound":
		failures += 1
		print("[THEME] FAIL fallback")
	var m := MapLoader.load_from_json("res://data/maps/op01_glass_house.json")
	var roundtrip := GreyboxMap.from_dict(m.to_dict())
	if m.tileset_theme != &"tactical_compound" or roundtrip.tileset_theme != m.tileset_theme:
		failures += 1
		print("[THEME] FAIL map field roundtrip")
	var warehouse := ThemeRegistry.for_id(&"industrial_warehouse")
	if warehouse.color(&"grid_color", Color.BLACK) != Color(0.18, 0.11, 0.05, 0.16):
		failures += 1
		print("[THEME] FAIL warehouse grid color")
	print("[THEME] RESULT %s failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
