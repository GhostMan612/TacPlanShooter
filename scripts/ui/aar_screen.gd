# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name AarScreen
extends Control


signal retry_requested
signal leave_requested

var result: Dictionary = {}


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


func _retry() -> void:
	retry_requested.emit()


func _leave() -> void:
	if not result.is_empty():
		leave_requested.emit()
	else:
		ScreenRouter.goto_stage(ScreenRouter.Stage.TITLE)
