# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name CampaignScreen
extends Control


const MISSION_PATHS: Array[String] = [
	"res://data/maps/op01_glass_house.json",
	"res://data/maps/op02_night_shift.json",
	"res://data/maps/op03_iron_shutter.json",
	"res://data/maps/op04_silent_relay.json",
	"res://data/maps/op05_penthouse_lock.json",
	"res://data/maps/op06_redline_terminal.json",
	"res://data/maps/op07_blackwater_pier.json",
	"res://data/maps/op08_cold_vault.json",
	"res://data/maps/op09_signal_tower.json",
	"res://data/maps/op10_sovereign_citadel.json",
]


var settings: Dictionary = {}
var missions: Array[Dictionary] = []


static func describe(path: String) -> Dictionary:
	var stem := path.get_file().get_basename()
	var number := stem.substr(2, 2)
	var fallback_title := stem.substr(5).replace("_", " ").capitalize()
	var info := {"path": path, "code": "OP-" + number, "title": fallback_title, "lighting": "", "floors": 1, "rp": 0}
	if not FileAccess.file_exists(path):
		return info
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return info
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return info
	var d: Dictionary = parsed
	info["title"] = String(d.get("title", fallback_title))
	info["lighting"] = String(d.get("lighting", "")).replace("_", " ")
	info["floors"] = int(d.get("floors", 1))
	info["rp"] = int(d.get("rp_reward", 0))
	return info


func _ready() -> void:
	var tm := ThemeManager.apply_saved()
	settings = ThemeManager.load_settings()
	var pal := tm.palette()
	var col := UiKit.build_screen(self, pal)
	col.add_child(UiKit.button("< BACK", _go_back, settings))
	col.add_child(UiKit.heading("CAMPAIGN", pal))
	col.add_child(UiKit.caption("Select an operation. Multi-floor operations currently load their ground floor only.", pal))
	for p in MISSION_PATHS:
		var info := describe(p)
		missions.append(info)
		var label := "%s  %s" % [String(info["code"]), String(info["title"]).to_upper()]
		var b := UiKit.button(label, _launch.bind(p), settings)
		b.name = String(info["code"])
		col.add_child(b)
		var meta := "%s  ·  %d floor%s  ·  %d RP" % [
			String(info["lighting"]) if String(info["lighting"]) != "" else "UNKNOWN LIGHT",
			int(info["floors"]),
			"" if int(info["floors"]) == 1 else "s",
			int(info["rp"]),
		]
		col.add_child(UiKit.caption(meta, pal))
	print("[TacPlan] screen=campaign missions=%d" % missions.size())


func _launch(path: String) -> void:
	ScreenRouter.set_param("map_path", path)
	ScreenRouter.set_param("return_stage", int(ScreenRouter.Stage.CAMPAIGN))
	ScreenRouter.goto_stage(ScreenRouter.Stage.IN_MISSION)


func _go_back() -> void:
	ScreenRouter.goto_stage(ScreenRouter.Stage.TITLE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if UiKit.is_back_event(event):
		_go_back()
