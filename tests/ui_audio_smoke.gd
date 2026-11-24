# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
extends SceneTree


func _initialize() -> void:
	BusGraph.ensure_buses()
	var ok := AudioServer.get_bus_index(&"BGM") >= 0
	var tm := ThemeManager.new()
	tm.set_theme(ThemeManager.Style.NIGHT_OPS)
	ok = ok and tm.current == ThemeManager.Style.NIGHT_OPS
	ok = ok and int(IconRegistry.count()) > 0
	var ar := AiArchetypes.by_name(&"heavy_gunner")
	ok = ok and int(ar["reaction_ticks"]) == 22
	var sr := ScreenRouter.new()
	ok = ok and sr.stage == ScreenRouter.Stage.SPLASH
	print("[HARNESS] ui_audio_smoke %s" % ("PASS" if ok else "FAIL"))
	quit()
