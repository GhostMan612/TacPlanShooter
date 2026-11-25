# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name AarScreen
extends Control


signal retry_requested
signal leave_requested
signal scrub_requested(tick: int)
signal replay_requested

var result: Dictionary = {}
var scrubber: HSlider = null
var scrub_label: Label = null


func _ready() -> void:
	var tm := ThemeManager.apply_saved()
	var settings := ThemeManager.load_settings()
	var pal := tm.palette()
	var col := UiKit.build_screen(self, pal)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var heading := "NO OPERATION RESULT"
	if not result.is_empty():
		heading = "OPERATION COMPLETE" if bool(result["completed"]) else "OPERATION FAILED"
		if bool(result["practice"]):
			heading = "PRACTICE COMPLETE" if bool(result["completed"]) else "PRACTICE FAILED"
	var title := UiKit.heading(heading, pal, 56)
	title.name = "ResultTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	if result.is_empty():
		col.add_child(UiKit.button("< MENU", _leave, settings))
		return
	col.add_child(UiKit.caption(String(result["reason"]), pal, false))
	var summary := "%d/%d checkpoints reached · %d/%d operatives standing · %.1f s" % [
		int(result["reached"]), int(result["checkpoints"]), int(result["alive"]),
		int(result["operatives"]), float(result["ticks"]) * SimWorld.DT,
	]
	col.add_child(UiKit.caption(summary, pal))
	col.add_child(UiKit.button("REPLAN", _retry, settings))
	col.add_child(UiKit.button("RETURN", _leave, settings))
	col.add_child(UiKit.heading("TIMELINE", pal, 28))
	var timeline_txt := "\n".join(PackedStringArray(_timeline_lines()))
	col.add_child(UiKit.caption(timeline_txt, pal, false))
	var max_tick := maxi(1, int(result.get("ticks", 0)))
	scrub_label = UiKit.caption("SCRUB TICK %d / %d" % [max_tick, max_tick], pal)
	scrub_label.name = "ScrubTickLabel"
	col.add_child(scrub_label)
	scrubber = HSlider.new()
	scrubber.name = "ReplayScrubber"
	scrubber.min_value = 0.0
	scrubber.max_value = float(max_tick)
	scrubber.step = 1.0
	scrubber.value = float(max_tick)
	scrubber.custom_minimum_size = Vector2(0.0, float(ThemeManager.touch_min(tm.accessible_scaling)) * 0.5)
	scrubber.value_changed.connect(_on_scrub_changed)
	col.add_child(scrubber)
	var replay := UiKit.button("REPLAY", _on_replay, settings)
	col.add_child(replay)


func _timeline_lines() -> Array[String]:
	var out: Array[String] = []
	if result.is_empty():
		return out
	var journal: Array = result.get("journal", [])
	for e in journal:
		var ev := String(e.get("ev", ""))
		var t_sec := float(e.get("t", 0)) * SimWorld.DT
		if ev == "go_issued":
			out.append("t=%.1fs · GO-CODE %s" % [t_sec, String(e.get("code", "")).to_upper()])
		elif ev == "breach_opened":
			out.append("t=%.1fs · BREACH (%d,%d)" % [t_sec, int(e.get("cx", 0)), int(e.get("cy", 0))])
		elif ev == "shot" and bool(e.get("hit", false)):
			out.append("t=%.1fs · HIT op%d -> op%d (-%d HP)" % [t_sec, int(e.get("op", 0)), int(e.get("target", 0)), int(e.get("dmg", 0))])
		elif ev == "kia":
			out.append("t=%.1fs · KIA op%d" % [t_sec, int(e.get("op", 0))])
		elif ev == "funnel_hit":
			out.append("t=%.1fs · FUNNEL op%d" % [t_sec, int(e.get("op", 0))])
		elif ev == "ai_callout":
			out.append("t=%.1fs · AI %s" % [t_sec, String(e.get("callout", ""))])
		if out.size() >= 10:
			break
	var ops := int(result["operatives"])
	var alive := int(result["alive"])
	var t := float(result["ticks"]) * SimWorld.DT
	out.append("Reached checkpoints: %d/%d at t=%.1fs" % [int(result["reached"]), int(result["checkpoints"]), t])
	out.append("Operatives standing: %d/%d (alive)" % [alive, ops])
	return out


func _on_scrub_changed(val: float) -> void:
	var tick_val := int(round(val))
	var max_tick := int(result.get("ticks", 0))
	if scrub_label != null:
		scrub_label.text = "SCRUB TICK %d / %d" % [tick_val, max_tick]
	scrub_requested.emit(tick_val)


func _on_replay() -> void:
	if not replay_requested.get_connections().is_empty():
		replay_requested.emit()
	else:
		ScreenRouter.goto_stage(ScreenRouter.Stage.LOADING)


func _retry() -> void:
	retry_requested.emit()


func _leave() -> void:
	if not result.is_empty():
		leave_requested.emit()
	else:
		ScreenRouter.goto_stage(ScreenRouter.Stage.TITLE)
