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
	col.add_child(UiKit.caption("v1.0.0  •  OFFLINE TACTICAL PLANNER", pal, false))
	col.add_child(UiKit.caption("Plan the breach. Commit the plan. Watch it hold.", pal))
	col.add_child(UiKit.spacer(48))
	_add(col, &"campaign", "CAMPAIGN", _on_campaign)
	_add(col, &"quick", "QUICK OPERATION  (OP-01)", _on_quick)
	_add(col, &"two_player", "2-PLAYER  CO-OP / PVP", _on_two_player)
	col.add_child(UiKit.caption("Pass-and-Play blind PvP/Co-Op or LAN UDP 7600 lockstep.", pal))
	_add(col, &"map_editor", "MAP EDITOR", _on_map_editor)
	_add(col, &"hq_armory", "HQ & ARMORY", _on_hq)
	_add(col, &"settings", "SETTINGS", _on_settings)
	_add(col, &"credits", "CREDITS", _on_credits)
	print("[TacPlan] screen=title buttons=%d" % buttons.size())
	if bool(ScreenRouter.get_param("autostart_quick", false)):
		ScreenRouter.clear_param("autostart_quick")
		call_deferred("_on_quick")


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
	ScreenRouter.clear_param("mission_loadout")
	ScreenRouter.clear_param("two_player_config")
	ScreenRouter.set_param("map_path", ScreenRouter.DEFAULT_MAP_PATH)
	ScreenRouter.set_param("return_stage", int(ScreenRouter.Stage.TITLE))
	ScreenRouter.goto_stage(ScreenRouter.Stage.IN_MISSION)


func _on_two_player() -> void:
	ScreenRouter.goto_stage(ScreenRouter.Stage.TWO_PLAYER)


func _on_map_editor() -> void:
	ScreenRouter.goto_stage(ScreenRouter.Stage.MAP_EDITOR)


func _on_hq() -> void:
	ScreenRouter.goto_stage(ScreenRouter.Stage.HQ)


func _on_settings() -> void:
	ScreenRouter.goto_stage(ScreenRouter.Stage.SETTINGS)


func _on_credits() -> void:
	ScreenRouter.goto_stage(ScreenRouter.Stage.CREDITS)
