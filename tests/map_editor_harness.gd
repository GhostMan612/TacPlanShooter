# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := 0
	failures += _test_state_undo()
	failures += _test_door_geometry_undo()
	failures += _test_ordered_content_undo()
	failures += _test_roundtrip()
	failures += _test_validator()
	failures += await _test_editor_scene()
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


func _test_door_geometry_undo() -> int:
	var st := MapEditorState.new()
	var cell := Vector2i(2, 2)
	st.map.solid_cells[cell] = true
	st.map.door_cells[cell] = true
	st.map.door_open[cell] = false
	st.map.door_states[cell] = &"LOCKED"
	st.map.wall_materials[cell] = &"ARMORED"
	var initial := st.map.to_dict()
	st.paint_wall(cell)
	var wall := st.map.to_dict()
	var ok: bool = st.map.solid_cells.has(cell) and not st.map.door_cells.has(cell)
	ok = ok and not st.map.door_open.has(cell) and not st.map.door_states.has(cell)
	st.undo()
	ok = ok and st.map.to_dict() == initial
	st.redo()
	ok = ok and st.map.to_dict() == wall
	st.paint_door(cell)
	var door := st.map.to_dict()
	ok = ok and st.map.door_state(cell) == &"OPEN"
	st.undo()
	ok = ok and st.map.to_dict() == wall
	st.redo()
	ok = ok and st.map.to_dict() == door
	print("[HARNESS] map_editor_door_geometry_undo %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_ordered_content_undo() -> int:
	var st := MapEditorState.new()
	var cell := Vector2i(3, 3)
	st.place_ai_spawn(cell, &"patrol_sentry")
	st.place_ai_spawn(cell, &"hostage_guard")
	st.place_objective(cell)
	st.place_objective(cell)
	st.paint_zone(&"INSERTION", [[3, 3], [4, 3]])
	st.paint_zone(&"INSERTION", [[7, 3]])
	st.paint_zone(&"INSERTION", [[3, 3], [4, 3]])
	st.place_jammer(cell)
	st.place_jammer(cell)
	var initial := st.map.to_dict().duplicate(true)
	var ok := st.erase_cell(cell)
	var erased := st.map.to_dict().duplicate(true)
	ok = ok and not st.cell_has_content(cell)
	st.undo()
	ok = ok and st.map.to_dict() == initial
	st.undo()
	ok = ok and st.map.jammer_nodes.size() == 1
	st.redo()
	ok = ok and st.map.to_dict() == initial
	st.redo()
	ok = ok and st.map.to_dict() == erased
	st.undo()
	for i in range(9):
		st.undo()
	ok = ok and not st.cell_has_content(cell) and st.map.insertion_zones.is_empty()
	for i in range(9):
		st.redo()
	ok = ok and st.map.to_dict() == initial
	print("[HARNESS] map_editor_ordered_content_undo %s" % ("PASS" if ok else "FAIL"))
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
	ok = ok and st2 != null and st2.map.ai_spawns.size() == 1
	var files := DirAccess.get_files_at("res://data/maps")
	for file in files:
		if file.ends_with(".json"):
			ok = ok and MapEditorState.from_json(FileAccess.get_file_as_string("res://data/maps/" + file)) != null
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


func _test_editor_scene() -> int:
	if not ScreenRouter.goto_stage(ScreenRouter.Stage.MAP_EDITOR):
		return 1
	await process_frame
	await process_frame
	var editor := current_scene as MapEditorScreen
	if editor == null:
		return 1
	var kept := editor.state
	var cell := Vector2i(4, 4)
	var pending := Vector2i(5, 5)
	kept.paint_zone(&"INSERTION", [[2, 2]])
	kept.paint_wall(cell)
	kept.paint_wall(pending)
	kept.undo()
	editor._set_tool(MapEditorState.Tool.ERASE)
	var ok := not editor._import_text("{malformed")
	ok = ok and not editor._import_text('{"w":16,"h":12,"solids":[[1]]}')
	ok = ok and not editor._import_text('{"width_cells":16,"walls":[{"a":[2,2],"b":[3,2],"floor":[]}]}')
	ok = ok and editor.state == kept and kept.map.solid_cells.has(cell)
	ok = ok and editor.status_label.text.begins_with("IMPORT FAILED")
	if not editor.playtest():
		return 1
	await process_frame
	await process_frame
	var planning := current_scene
	if planning == null or not planning.has_method("_go_back"):
		return 1
	var playtest_map: GreyboxMap = planning.get("map")
	if playtest_map == null:
		return 1
	ok = ok and playtest_map.solid_cells.has(cell)
	playtest_map.solid_cells.erase(cell)
	planning.call("_go_back")
	await process_frame
	await process_frame
	var restored := current_scene as MapEditorScreen
	if restored == null:
		return 1
	ok = ok and restored.state == kept and kept.map.solid_cells.has(cell)
	ok = ok and kept.current_tool == MapEditorState.Tool.ERASE
	restored._run_action(MapEditorState.Tool.REDO)
	ok = ok and kept.map.solid_cells.has(pending)
	restored._run_action(MapEditorState.Tool.UNDO)
	restored._run_action(MapEditorState.Tool.UNDO)
	ok = ok and not kept.map.solid_cells.has(cell) and not kept.map.solid_cells.has(pending)
	ok = ok and ScreenRouter.get_param(MapEditorScreen.BUFFER_PARAM) == null
	ok = ok and restored._import_text('{"w":12,"h":8,"solids":[[2,2]]}')
	ok = ok and restored.state != kept and restored.state.map.width_cells == 12
	restored._run_action(MapEditorState.Tool.UNDO)
	ok = ok and restored.state.map.solid_cells.has(Vector2i(2, 2))
	print("[HARNESS] map_editor_playtest_history %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1
