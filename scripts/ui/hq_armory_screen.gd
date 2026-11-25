# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name ArmoryScreen
extends Control


const ROLE_NAMES: Array[String] = ["SQUAD LEADER", "POINTMAN", "BREACHER", "SHIELD / HEAVY", "TECH / DRONE OPERATOR", "MARKSMAN / OVERWATCH", "MEDIC / RESCUE"]
const DEFAULT_RECRUITS: Array = [
	[&"vanguard", UnitProfile.Role.POINTMAN],
	[&"vector", UnitProfile.Role.TECH_DRONE_OPERATOR],
	[&"sledge", UnitProfile.Role.BREACHER],
	[&"aegis", UnitProfile.Role.SHIELD_HEAVY],
	[&"specter", UnitProfile.Role.MARKSMAN_OVERWATCH],
	[&"lifeline", UnitProfile.Role.MEDIC_RESCUE],
]


var armory := ArmoryCatalog.new()
var roster: Array[UnitProfile] = []
var settings: Dictionary = {}
var progression: ProgressionSave = null
var _rp_label: Label = null


static func default_roster() -> Array[UnitProfile]:
	var out: Array[UnitProfile] = []
	for i in range(DEFAULT_RECRUITS.size()):
		var entry: Array = DEFAULT_RECRUITS[i]
		var p := UnitProfile.new()
		p.operative_id = i
		p.codename = entry[0]
		p.assign_role(int(entry[1]))
		out.append(p)
	return out


static func role_name(role: int) -> String:
	if role < 0 or role >= ROLE_NAMES.size():
		return "UNASSIGNED"
	return ROLE_NAMES[role]


static func item_label(item: StringName) -> String:
	var s := String(item)
	var cut := s.find("_")
	if cut >= 0:
		s = s.substr(cut + 1)
	return s.replace("_", " ").to_upper()


static func unlock_cost(item: StringName) -> int:
	var s := String(item)
	if s.begins_with("attachment_") or s.begins_with("tool_"):
		return 25
	return 40


func try_equip(profile: UnitProfile, item: StringName) -> bool:
	if not armory.is_unlocked(item):
		return false
	profile.equip(item)
	return true


func valid_for_pvp(profile: UnitProfile) -> bool:
	return profile.loadout_points() <= armory.STANDARDIZED_LOADOUT_POINTS


func _ready() -> void:
	progression = ProgressionSave.load_from_disk()
	for u in progression.unlocked_items():
		armory.unlock(StringName(u))
	if roster.is_empty():
		var base := default_roster()
		var by_id: Dictionary = {}
		for sp in progression.profiles:
			var prof := sp as UnitProfile
			if prof != null:
				by_id[prof.operative_id] = prof
		for b in base:
			roster.append(by_id.get(b.operative_id, b))
	_rebuild_ui()
	print("[TacPlan] screen=hq roster=%d rp=%d" % [roster.size(), int(progression.campaign_state.get("total_rp", 0))])


func _rebuild_ui() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var tm := ThemeManager.apply_saved()
	settings = ThemeManager.load_settings()
	var pal := tm.palette()
	var col := UiKit.build_screen(self, pal)
	col.add_child(UiKit.button("< BACK", _go_back, settings))
	col.add_child(UiKit.heading("HQ & ARMORY", pal))
	var rp := int(progression.campaign_state.get("total_rp", 0)) if progression != null else 0
	_rp_label = UiKit.heading("AVAILABLE RP: %d" % rp, pal, 34)
	_rp_label.name = "AvailableRpLabel"
	col.add_child(_rp_label)
	col.add_child(UiKit.caption("Earn RP by completing Campaign operations, then unlock gear below for Mission Prep.", pal))
	col.add_child(UiKit.heading("ROSTER", pal, 44))
	for p in roster:
		col.add_child(_roster_card(p, pal))
	col.add_child(UiKit.heading("ARMORY", pal, 44))
	col.add_child(UiKit.caption("PvP standardized loadout budget: %d points." % armory.STANDARDIZED_LOADOUT_POINTS, pal))
	_add_category(col, pal, "WEAPONS", armory.WEAPONS, rp)
	_add_category(col, pal, "ATTACHMENTS", armory.ATTACHMENTS, rp)
	_add_category(col, pal, "ARMOR", armory.ARMOR_TIERS, rp)
	_add_category(col, pal, "TACTICAL TOOLS", armory.TACTICAL_TOOLS, rp)
	_add_category(col, pal, "DRONES", armory.DRONES, rp)
	_add_category(col, pal, "VEHICLES", armory.VEHICLES, rp)


func _roster_card(p: UnitProfile, pal: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var name_label := Label.new()
	name_label.text = String(p.codename).to_upper()
	name_label.add_theme_color_override("font_color", pal["accent"])
	box.add_child(name_label)
	var detail := Label.new()
	detail.text = "%s  ·  XP %d  ·  %d ribbon%s" % [role_name(p.role), p.xp, p.mission_ribbons.size(), "" if p.mission_ribbons.size() == 1 else "s"]
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(detail)
	return card


func _add_category(col: VBoxContainer, pal: Dictionary, title: String, items: Array[StringName], available_rp: int) -> void:
	var unlocked := 0
	for item in items:
		if armory.is_unlocked(item):
			unlocked += 1
	col.add_child(UiKit.caption("%s  (%d / %d unlocked)" % [title, unlocked, items.size()], pal, false))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in items:
		if armory.is_unlocked(item):
			var l := Label.new()
			l.text = "  [UNLOCKED]  " + item_label(item)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.add_theme_color_override("font_color", pal["ink"])
			list.add_child(l)
		else:
			var cost := unlock_cost(item)
			var b := UiKit.button("UNLOCK %s  (%d RP)" % [item_label(item), cost], _on_unlock_pressed.bind(item, cost), settings)
			b.name = "Unlock_" + String(item)
			b.custom_minimum_size = Vector2(0, 56)
			b.add_theme_font_size_override("font_size", 20)
			b.clip_text = true
			b.disabled = available_rp < cost
			list.add_child(b)
	col.add_child(list)


func _on_unlock_pressed(item: StringName, cost: int) -> void:
	if progression == null:
		return
	if progression.unlock_item(item, cost):
		armory.unlock(item)
		progression.save_to_disk()
		var ta := get_node_or_null("/root/TacticalAudio")
		if ta != null:
			ta.play_blip(&"")
		_rebuild_ui()


func _go_back() -> void:
	ScreenRouter.goto_stage(ScreenRouter.Stage.TITLE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if UiKit.is_back_event(event):
		_go_back()
