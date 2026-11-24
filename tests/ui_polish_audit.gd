# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
extends SceneTree


func _initialize() -> void:
	var failures := 0
	failures += _test_theme_apply()
	failures += _test_squad_hud_control()
	failures += _test_map_renderer_palette()
	failures += _test_validator_checks()
	failures += _test_editor_erase_undo()
	print("[HARNESS] RESULT %s failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _test_theme_apply() -> int:
	var ok := true
	var bgs: Array[Color] = []
	for style in range(ThemeManager.style_count()):
		var pal := ThemeManager.palette_for(style)
		for k in pal.keys():
			var c: Color = pal[k]
			ok = ok and c.r <= 1.0 and c.g <= 1.0 and c.b <= 1.0 and c.a <= 1.0
		var bg: Color = pal["bg"]
		ok = ok and not bgs.has(bg)
		bgs.append(bg)
		var t := ThemeManager.build_theme(pal, false)
		ok = ok and t.has_stylebox("normal", "Button") and t.has_stylebox("pressed", "Button")
		ok = ok and t.has_color("font_color", "Button") and t.has_color("font_color", "Label")
		ok = ok and t.default_font_size >= ThemeManager.FONT_SIZE_STANDARD
		var normal := t.get_stylebox("normal", "Button")
		ok = ok and normal.get_minimum_size().y + float(t.default_font_size) >= float(ThemeManager.TOUCH_MIN_STANDARD) - 24.0
	var tm := ThemeManager.new()
	tm.set_theme(ThemeManager.Style.NIGHT_OPS)
	tm.apply()
	ok = ok and tm.applied_theme != null and root.theme == tm.applied_theme
	print("[HARNESS] ui_theme_apply %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_squad_hud_control() -> int:
	var w := SimWorld.new()
	w.setup(GreyboxMap.build_default(), 7)
	var none: Array[AgentCommand] = []
	w.add_operative(0, Vector2i(2, 2), none)
	w.add_operative(1, Vector2i(3, 2), none)
	w.add_operative(2, Vector2i(4, 2), none)
	var sq := SquadConfig.new()
	sq.add_member(&"red", 0)
	sq.add_member(&"red", 1)
	sq.add_member(&"blue", 2)
	var h := SquadHud.new()
	h.squads = sq
	root.add_child(h)
	h.refresh(w)
	var ok := h is Control and h.mouse_filter == Control.MOUSE_FILTER_IGNORE
	ok = ok and h.card_count() == 2
	ok = ok and h.callsign(0) == "R1" and h.callsign(1) == "R2" and h.callsign(2) == "B1"
	ok = ok and h.operative_button(2) != null
	h.touch_operative(2)
	ok = ok and h.selected_op == 2
	root.remove_child(h)
	h.free()
	print("[HARNESS] ui_squad_hud_control %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_map_renderer_palette() -> int:
	var r := MapRenderer.new()
	r.setup(GreyboxMap.build_default())
	var pal := ThemeManager.palette_for(ThemeManager.Style.LIGHT_BLUEPRINT)
	r.apply_palette(pal)
	var ok: bool = r._color("bg", Color.BLACK) == pal["bg"] and r._color("missing", Color.BLACK) == Color.BLACK
	ok = ok and MapRenderer.col_letter(0) == "A" and MapRenderer.col_letter(25) == "Z" and MapRenderer.col_letter(26) == "AA"
	ok = ok and PlanBoard.squad_color(&"red").r <= 1.0 and PlanBoard.squad_color(&"red").g < 0.5
	r.free()
	print("[HARNESS] ui_map_renderer %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_validator_checks() -> int:
	var m := GreyboxMap.build_default()
	m.objectives.append({"cell": [0, 0], "id": "1"})
	var ok := not MapEditorValidator.validate(m).is_empty()
	var walled := GreyboxMap.build_default()
	walled.door_cells.erase(Vector2i(8, 6))
	walled.solid_cells[Vector2i(8, 6)] = true
	walled.insertion_zones.append({"cells": [[2, 2]]})
	walled.objectives.append({"cell": [12, 4], "id": "1"})
	var flags := MapEditorValidator.validate(walled)
	var unreachable := false
	for f in flags:
		if String(f["reason"]) == "unreachable from insertion":
			unreachable = true
	ok = ok and unreachable
	var open := GreyboxMap.build_default()
	open.insertion_zones.append({"cells": [[2, 2]]})
	open.objectives.append({"cell": [12, 4], "id": "1"})
	ok = ok and MapEditorValidator.validate(open, true).is_empty()
	ok = ok and MapEditorValidator.cell_of({"cell": [7, 6]}) == Vector2i(7, 6) and MapEditorValidator.cell_of([3, 4]) == Vector2i(3, 4)
	print("[HARNESS] ui_validator_checks %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_editor_erase_undo() -> int:
	var st := MapEditorState.new()
	var c := Vector2i(4, 4)
	st.paint_wall(c)
	st.place_objective(Vector2i(5, 5))
	var ok := st.erase_cell(c) and not st.map.solid_cells.has(c)
	st.undo()
	ok = ok and st.map.solid_cells.has(c)
	ok = ok and st.erase_cell(Vector2i(5, 5)) and st.map.objectives.is_empty()
	st.undo()
	ok = ok and st.map.objectives.size() == 1
	ok = ok and not st.erase_cell(Vector2i(9, 9))
	var text := st.to_json()
	var back := MapLoader.load_from_string(text)
	ok = ok and back.solid_cells.has(c) and back.objectives.size() == 1
	print("[HARNESS] ui_editor_erase_undo %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1
