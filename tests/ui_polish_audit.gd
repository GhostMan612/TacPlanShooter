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
	var ok := true
	for name in [&"dark_tactical", &"light_blueprint", &"night_ops"]:
		for k in ThemeManager.PALETTES[name].keys():
			var c: Color = ThemeManager.PALETTES[name][k]
			ok = ok and (c.r <= 1.0 and c.g <= 1.0 and c.b <= 1.0 and c.a <= 1.0)
	var a := ThemeManager.PALETTES[&"dark_tactical"]["bg"]
	var b := ThemeManager.PALETTES[&"light_blueprint"]["bg"]
	var c := ThemeManager.PALETTES[&"night_ops"]["bg"]
	ok = ok and a != b and b != c and a != c
	ok = ok and tm.applied_theme != null
	print("[HARNESS] ui_theme_apply %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_squad_hud_control() -> int:
	var h := SquadHud.new()
	h.world = SimWorld.new()
	h._ready()
	var ok := h is Control and h.get_child_count() > 0
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
