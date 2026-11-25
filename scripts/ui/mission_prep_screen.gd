# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name MissionPrepScreen
extends Control


const TAB_NAMES: Array[String] = ["BRIEF", "INTEL", "ROSTER", "KIT", "SQUAD"]
const WEAPON_OPTIONS: Array[Dictionary] = [
	{"id": "weapon_smg_standard", "label": "SMG 9MM", "caliber": "9mm"},
	{"id": "weapon_carbine_compact", "label": "CARBINE 5.56", "caliber": "5.56"},
	{"id": "weapon_rifle_ap", "label": "AP RIFLE 7.62", "caliber": "7.62"},
]
const ARMOR_OPTIONS: Array[Dictionary] = [
	{"id": "armor_light_iia", "label": "LIGHT IIA", "armor_class": "light"},
	{"id": "armor_medium_ii", "label": "MEDIUM II", "armor_class": "medium"},
	{"id": "armor_heavy_iii_iv", "label": "HEAVY III-IV", "armor_class": "heavy"},
	{"id": "armor_shield", "label": "SHIELD", "armor_class": "shield"},
]
const TOOL_OPTIONS: Array[Dictionary] = [
	{"id": "tool_demolitions", "label": "DEMOLITIONS", "heartbeat_radius": 0},
	{"id": "tool_underdoor_cam", "label": "UNDERDOOR CAM", "heartbeat_radius": 2},
	{"id": "tool_heartbeat_sensor", "label": "HEARTBEAT SENSOR", "heartbeat_radius": 4},
]


var settings: Dictionary = {}
var map_path: String = ScreenRouter.DEFAULT_MAP_PATH
var map: GreyboxMap = null
var info: Dictionary = {}
var intel: Dictionary = {}
var roster: Array[UnitProfile] = []
var unlocked: Array[String] = []
var selected_ids: Array[int] = [0, 1]
var kit_choices: Dictionary = {}
var squad_choices: Dictionary = {}
var active_tab: int = 0
var tab_buttons: Array[Button] = []
var body_box: VBoxContainer = null
var deploy_button: Button = null
var _pal: Dictionary = {}


func _ready() -> void:
	var tm := ThemeManager.apply_saved()
	settings = ThemeManager.load_settings()
	_pal = tm.palette()
	var p_param: Variant = ScreenRouter.get_param("map_path", ScreenRouter.DEFAULT_MAP_PATH)
	if typeof(p_param) == TYPE_STRING and String(p_param) != "":
		map_path = String(p_param)
	if FileAccess.file_exists(map_path):
		map = MapLoader.load_from_json(map_path)
	if map == null or map.width_cells <= 0:
		map = GreyboxMap.build_default()
	info = CampaignScreen.describe(map_path)
	intel = MissionPrepPanels.intel_summary(map)
	var ps := ProgressionSave.load_from_disk()
	unlocked = ps.unlocked_items()
	roster = ArmoryScreen.default_roster()
	for idx in range(roster.size()):
		var base := MissionPrepPanels.default_unit_kit(idx)
		kit_choices[idx] = {
			"weapon_idx": 1 if idx % 2 == 0 else 0,
			"armor_idx": 0,
			"tool_idx": 0 if idx % 2 == 0 else 1,
		}
		squad_choices[idx] = String(base["squad"])
	_build_shell()
	_refresh_tab()
	print("[TacPlan] screen=prep map=%s tabs=%d" % [String(info.get("code", "OP-01")), TAB_NAMES.size()])


func _build_shell() -> void:
	var col := UiKit.build_screen(self, _pal)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	var back_btn := UiKit.button("< BACK", _go_back, settings)
	back_btn.add_theme_font_size_override("font_size", 22)
	top_row.add_child(back_btn)
	var quick_btn := UiKit.button("QUICK DEPLOY >", quick_deploy, settings)
	quick_btn.name = "QuickDeployButton"
	quick_btn.add_theme_font_size_override("font_size", 22)
	top_row.add_child(quick_btn)
	col.add_child(top_row)
	col.add_child(UiKit.heading("%s · %s" % [String(info.get("code", "OP-01")), String(info.get("title", "OPERATION")).to_upper()], _pal, 44))
	var fl := int(info.get("floors", 1))
	col.add_child(UiKit.caption("%s · %d floor%s · +%d RP reward" % [
		String(info.get("lighting", "TACTICAL")).to_upper(),
		fl,
		"" if fl == 1 else "s",
		int(info.get("rp", 0)),
	], _pal))
	var tab_row := HBoxContainer.new()
	tab_row.name = "PrepTabs"
	tab_row.add_theme_constant_override("separation", 6)
	tab_buttons.clear()
	for i in range(TAB_NAMES.size()):
		var b := UiKit.button(TAB_NAMES[i], _select_tab.bind(i), settings)
		b.name = "PrepTab_" + TAB_NAMES[i]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 56)
		b.add_theme_font_size_override("font_size", 20)
		b.clip_text = true
		tab_row.add_child(b)
		tab_buttons.append(b)
	col.add_child(tab_row)
	body_box = VBoxContainer.new()
	body_box.name = "PrepBody"
	body_box.add_theme_constant_override("separation", 10)
	body_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(body_box)
	col.add_child(UiKit.spacer(12))
	deploy_button = UiKit.button("DEPLOY TO PLANNING", deploy_to_planning, settings)
	deploy_button.name = "DeployButton"
	col.add_child(deploy_button)


func _select_tab(idx: int) -> void:
	active_tab = clampi(idx, 0, TAB_NAMES.size() - 1)
	_refresh_tab()


func _refresh_tab() -> void:
	for i in range(tab_buttons.size()):
		tab_buttons[i].set_pressed_no_signal(i == active_tab)
	if deploy_button != null:
		deploy_button.text = "DEPLOY TO PLANNING  (%d OPS)" % selected_ids.size()
	if body_box == null:
		return
	for child in body_box.get_children():
		body_box.remove_child(child)
		child.queue_free()
	match active_tab:
		0:
			_populate_brief()
		1:
			_populate_intel()
		2:
			_populate_roster()
		3:
			_populate_kit()
		4:
			_populate_squad()


func _populate_brief() -> void:
	body_box.add_child(UiKit.heading("SITUATION BRIEFING", _pal, 32))
	var objs := int(intel.get("objectives", 0))
	var exts := int(intel.get("extractions", 0))
	var fls := int(intel.get("floors", 1))
	var txt := "Objectives: %d checkpoint%s.\nExtraction zones: %d.\nStructure: %d floor%s (%dx%d grid)." % [
		objs,
		"" if objs == 1 else "s",
		exts,
		fls,
		"" if fls == 1 else "s",
		map.width_cells,
		map.height_cells,
	]
	if fls > 1:
		txt += "\nUse cyan stairwell tiles to transition between F1 and upper floors during planning."
	body_box.add_child(UiKit.caption(txt, _pal, false))
	body_box.add_child(UiKit.caption("ROE: Plan synchronized GO-Codes (Alpha-Delta) and node stances/actions before EXECUTE.", _pal))


func _populate_intel() -> void:
	body_box.add_child(UiKit.heading("THREAT & FLOOR INTEL", _pal, 32))
	var counts: Dictionary = intel.get("archetypes", {})
	var force_lines := PackedStringArray()
	for k in counts.keys():
		force_lines.append("%s x%d" % [String(k), int(counts[k])])
	var force_str := ", ".join(force_lines) if not force_lines.is_empty() else "NONE DETECTED"
	var chokes: Array = intel.get("chokepoints", [])
	var choke_str := ", ".join(PackedStringArray(chokes)) if not chokes.is_empty() else "NONE MARKED"
	var summary := "Confirmed Hostiles: %d (%s)\nBreach Doors: %d\nFatal Funnels: %s" % [
		int(intel.get("enemies", 0)),
		force_str,
		int(intel.get("doors", 0)),
		choke_str,
	]
	body_box.add_child(UiKit.caption(summary, _pal, false))


func _populate_roster() -> void:
	body_box.add_child(UiKit.heading("SELECT SQUAD (2 TO 4 OPS)", _pal, 32))
	for i in range(roster.size()):
		var p := roster[i]
		var active := selected_ids.has(i)
		var mark := "[ACTIVE] " if active else "[BENCH]  "
		var label := "%s%s  (%s)" % [mark, String(p.codename).to_upper(), ArmoryScreen.role_name(p.role)]
		var b := UiKit.button(label, _toggle_operative.bind(i), settings)
		b.name = "RosterToggle_%d" % i
		b.custom_minimum_size = Vector2(0, 56)
		b.add_theme_font_size_override("font_size", 20)
		b.clip_text = true
		body_box.add_child(b)


func toggle_operative(idx: int) -> bool:
	if idx < 0 or idx >= roster.size():
		return false
	if selected_ids.has(idx):
		if selected_ids.size() <= 2:
			return false
		selected_ids.erase(idx)
		return true
	if selected_ids.size() >= 4:
		return false
	selected_ids.append(idx)
	selected_ids.sort()
	return true


func _toggle_operative(idx: int) -> void:
	toggle_operative(idx)
	_refresh_tab()


func _populate_kit() -> void:
	body_box.add_child(UiKit.heading("WEAPONS, ARMOR & GEAR", _pal, 32))
	for idx in selected_ids:
		var prof := roster[idx]
		var kc: Dictionary = kit_choices.get(idx, {"weapon_idx": 0, "armor_idx": 0, "tool_idx": 0})
		var w_opt: Dictionary = WEAPON_OPTIONS[int(kc["weapon_idx"]) % WEAPON_OPTIONS.size()]
		var a_opt: Dictionary = ARMOR_OPTIONS[int(kc["armor_idx"]) % ARMOR_OPTIONS.size()]
		var t_opt: Dictionary = TOOL_OPTIONS[int(kc["tool_idx"]) % TOOL_OPTIONS.size()]
		body_box.add_child(UiKit.caption("%s · %s" % [String(prof.codename).to_upper(), ArmoryScreen.role_name(prof.role)], _pal, false))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var wb := UiKit.button(String(w_opt["label"]), _cycle_kit.bind(idx, "weapon_idx", WEAPON_OPTIONS, false), settings)
		wb.custom_minimum_size = Vector2(0, 54)
		wb.add_theme_font_size_override("font_size", 18)
		wb.clip_text = true
		row.add_child(wb)
		var ab := UiKit.button(String(a_opt["label"]), _cycle_kit.bind(idx, "armor_idx", ARMOR_OPTIONS, false), settings)
		ab.custom_minimum_size = Vector2(0, 54)
		ab.add_theme_font_size_override("font_size", 18)
		ab.clip_text = true
		row.add_child(ab)
		var tb := UiKit.button(String(t_opt["label"]), _cycle_kit.bind(idx, "tool_idx", TOOL_OPTIONS, true), settings)
		tb.custom_minimum_size = Vector2(0, 54)
		tb.add_theme_font_size_override("font_size", 18)
		tb.clip_text = true
		row.add_child(tb)
		body_box.add_child(row)


func _cycle_kit(op_idx: int, field: String, options: Array[Dictionary], allow_locked: bool) -> void:
	var kc: Dictionary = kit_choices.get(op_idx, {"weapon_idx": 0, "armor_idx": 0, "tool_idx": 0})
	var cur := int(kc.get(field, 0))
	for step in range(1, options.size() + 1):
		var cand := (cur + step) % options.size()
		var item_id := String(options[cand]["id"])
		if allow_locked or unlocked.has(item_id):
			kc[field] = cand
			break
	kit_choices[op_idx] = kc
	_refresh_tab()


func _populate_squad() -> void:
	body_box.add_child(UiKit.heading("FIRETEAM ASSIGNMENTS", _pal, 32))
	var per_sq := {}
	for idx in selected_ids:
		var prof := roster[idx]
		var sq := String(squad_choices.get(idx, "red"))
		var nth := int(per_sq.get(sq, 0)) + 1
		per_sq[sq] = nth
		var prefix := "Y" if sq == "gold" else sq.substr(0, 1).to_upper()
		var b := UiKit.button("%s  ->  %s (%s%d)" % [String(prof.codename).to_upper(), sq.to_upper(), prefix, nth], _cycle_squad.bind(idx), settings)
		b.custom_minimum_size = Vector2(0, 56)
		b.add_theme_font_size_override("font_size", 20)
		b.clip_text = true
		body_box.add_child(b)


func _cycle_squad(op_idx: int) -> void:
	var cur := StringName(String(squad_choices.get(op_idx, "red")))
	var i := SquadConfig.SQUADS.find(cur)
	var next_sq := SquadConfig.SQUADS[(i + 1) % SquadConfig.SQUADS.size()]
	squad_choices[op_idx] = String(next_sq)
	_refresh_tab()


func build_loadout() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for idx in selected_ids:
		var prof := roster[idx]
		var kc: Dictionary = kit_choices.get(idx, {"weapon_idx": 0, "armor_idx": 0, "tool_idx": 0})
		var w_opt: Dictionary = WEAPON_OPTIONS[int(kc["weapon_idx"]) % WEAPON_OPTIONS.size()]
		var a_opt: Dictionary = ARMOR_OPTIONS[int(kc["armor_idx"]) % ARMOR_OPTIONS.size()]
		var t_opt: Dictionary = TOOL_OPTIONS[int(kc["tool_idx"]) % TOOL_OPTIONS.size()]
		out.append({
			"roster_id": idx,
			"codename": String(prof.codename).to_upper(),
			"squad": String(squad_choices.get(idx, "red")),
			"caliber": String(w_opt["caliber"]),
			"armor_class": String(a_opt["armor_class"]),
			"heartbeat_radius": int(t_opt["heartbeat_radius"]),
		})
	return out


func deploy_to_planning() -> void:
	ScreenRouter.clear_param("two_player_config")
	ScreenRouter.set_param("map_path", map_path)
	ScreenRouter.set_param("mission_loadout", build_loadout())
	ScreenRouter.set_param("return_stage", int(ScreenRouter.Stage.CAMPAIGN))
	ScreenRouter.goto_stage(ScreenRouter.Stage.IN_MISSION)


func quick_deploy() -> void:
	ScreenRouter.clear_param("mission_loadout")
	ScreenRouter.clear_param("two_player_config")
	ScreenRouter.set_param("map_path", map_path)
	ScreenRouter.set_param("return_stage", int(ScreenRouter.Stage.CAMPAIGN))
	ScreenRouter.goto_stage(ScreenRouter.Stage.IN_MISSION)


func _go_back() -> void:
	var target := int(ScreenRouter.get_param("return_stage", int(ScreenRouter.Stage.CAMPAIGN)))
	ScreenRouter.goto_stage(target)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if UiKit.is_back_event(event):
		_go_back()
