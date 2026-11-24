# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
extends SceneTree


func _initialize() -> void:
	var failures := 0
	failures += _test_state_undo()
	failures += _test_roundtrip()
	failures += _test_validator()
	print("[HARNESS] RESULT %s failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _test_state_undo() -> int:
	var st := MapEditorState.new()
	st.paint_wall(Vector2i(1, 1))
	st.paint_wall(Vector2i(2, 2))
	var ok := st.map.solid_cells.has(Vector2i(2, 2))
	st.undo()
	ok = ok and not st.map.solid_cells.has(Vector2i(2, 2))
	st.redo()
	ok = ok and st.map.solid_cells.has(Vector2i(2, 2))
	print("[HARNESS] map_editor_state_undo %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_roundtrip() -> int:
	var st := MapEditorState.new()
	st.map.width_cells = 16
	st.map.height_cells = 12
	st.place_ai_spawn(Vector2i(3, 3), &"patrol_sentry")
	st.place_objective(Vector2i(10, 4))
	var text := st.to_json()
	var m := MapLoader.load_from_string(text)
	var ok: bool = m.ai_spawns.size() == 1 and m.objectives.size() == 1
	ok = ok and m.in_bounds(Vector2i(3, 3)) and m.in_bounds(Vector2i(10, 4))
	var st2 := MapEditorState.from_json(text)
	ok = ok and st2.map.ai_spawns.size() == 1
	print("[HARNESS] map_editor_roundtrip %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_validator() -> int:
	var m := GreyboxMap.build_default()
	m.objectives.append({"cell": [0, 0], "id": "1"})
	var flags := MapEditorValidator.validate(m)
	var ok := flags.size() >= 1
	var m2 := GreyboxMap.build_default()
	m2.objectives.append({"cell": [5, 5], "id": "1"})
	ok = ok and MapEditorValidator.validate(m2).is_empty()
	print("[HARNESS] map_editor_validator %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1
