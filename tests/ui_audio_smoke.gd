# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
extends SceneTree

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
	var ta_script := load("res://scripts/audio/tactical_audio.gd") as GDScript
	ok = ok and ta_script != null
	if ta_script != null:
		var ta: Node = ta_script.new()
		ta._setup_buses()
		var amb := AudioServer.get_bus_index(&"Ambient")
		ok = ok and amb >= 0 and AudioServer.get_bus_effect_count(amb) >= 1
		ta._duck_ambient(0.45)
		ok = ok and is_equal_approx(ta._duck_factor, 0.45)
		ta._on_operative_damaged(0, 40)
		ok = ok and ta._heartbeat_time_left > 0.0
		ta._unduck()
		ok = ok and is_equal_approx(ta._duck_factor, 1.0)
		ta.free()
	print("[HARNESS] ui_audio_smoke %s" % ("PASS" if ok else "FAIL"))
	quit()
