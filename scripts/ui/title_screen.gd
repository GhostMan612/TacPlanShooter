# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name TitleScreen
extends Control


var settings: Dictionary = {}
var buttons: Dictionary = {}


func _ready() -> void:
	var tm := ThemeManager.apply_saved()
	settings = ThemeManager.load_settings()
	var pal := tm.palette()
	var col := UiKit.build_screen(self, pal)
	col.add_child(UiKit.spacer(48))
	col.add_child(UiKit.heading("TACPLAN SHOOTER", pal, 88))
	col.add_child(UiKit.caption("Plan the breach. Commit the plan. Watch it hold.", pal))
	col.add_child(UiKit.spacer(48))
	_add(col, &"campaign", "CAMPAIGN", _on_campaign)
	_add(col, &"quick", "QUICK OPERATION  (OP-01)", _on_quick)
	var two := _add(col, &"two_player", "2-PLAYER  CO-OP / PVP", Callable())
	two.disabled = true
	col.add_child(UiKit.caption("2-Player needs the LAN lockstep transport, which is not available yet.", pal))
	_add(col, &"map_editor", "MAP EDITOR", _on_map_editor)
	_add(col, &"hq_armory", "HQ & ARMORY", _on_hq)
	_add(col, &"settings", "SETTINGS", _on_settings)
	_add(col, &"credits", "CREDITS", _on_credits)
	print("[TacPlan] screen=title buttons=%d" % buttons.size())


func _add(col: VBoxContainer, key: StringName, label: String, cb: Callable) -> Button:
	var b := UiKit.button(label, cb, settings)
	b.name = String(key)
	col.add_child(b)
	buttons[key] = b
	return b


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if UiKit.is_back_event(event):
		get_tree().quit()


func _on_campaign() -> void:
	ScreenRouter.goto_stage(ScreenRouter.Stage.CAMPAIGN)


func _on_quick() -> void:
	ScreenRouter.set_param("map_path", ScreenRouter.DEFAULT_MAP_PATH)
	ScreenRouter.set_param("return_stage", int(ScreenRouter.Stage.TITLE))
	ScreenRouter.goto_stage(ScreenRouter.Stage.IN_MISSION)


func _on_map_editor() -> void:
	ScreenRouter.goto_stage(ScreenRouter.Stage.MAP_EDITOR)


func _on_hq() -> void:
	ScreenRouter.goto_stage(ScreenRouter.Stage.HQ)


func _on_settings() -> void:
	ScreenRouter.goto_stage(ScreenRouter.Stage.SETTINGS)


func _on_credits() -> void:
	ScreenRouter.goto_stage(ScreenRouter.Stage.CREDITS)
