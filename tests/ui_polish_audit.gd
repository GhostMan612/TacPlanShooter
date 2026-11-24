# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
extends SceneTree


func _initialize() -> void:
	var failures := 0
	failures += _test_theme_apply()
	failures += _test_squad_hud_control()
	failures += _test_map_renderer_draw()
	print("[HARNESS] RESULT %s failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _test_theme_apply() -> int:
	var tm := ThemeManager.new()
	tm.set_theme(ThemeManager.Style.NIGHT_OPS)
	tm.apply()
	var ok := tm.current == ThemeManager.Style.NIGHT_OPS and tm.applied_theme != null
	print("[HARNESS] ui_theme_apply %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_squad_hud_control() -> int:
	var h := SquadHud.new()
	h.world = SimWorld.new()
	var ok := h is Control and h.world != null
	print("[HARNESS] ui_squad_hud_control %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_map_renderer_draw() -> int:
	var r := MapRenderer.new()
	var m := GreyboxMap.build_default()
	r.setup(m)
	r.queue_redraw()
	var ok := r.map != null and r.map.get_wall_segments().size() > 0
	print("[HARNESS] ui_map_renderer %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1
