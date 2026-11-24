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


func try_equip(profile: UnitProfile, item: StringName) -> bool:
	if not armory.is_unlocked(item):
		return false
	profile.equip(item)
	return true


func valid_for_pvp(profile: UnitProfile) -> bool:
	return profile.loadout_points() <= armory.STANDARDIZED_LOADOUT_POINTS


func _ready() -> void:
	var tm := ThemeManager.apply_saved()
	settings = ThemeManager.load_settings()
	var pal := tm.palette()
	if roster.is_empty():
		roster = default_roster()
	var col := UiKit.build_screen(self, pal)
	col.add_child(UiKit.button("< BACK", _go_back, settings))
	col.add_child(UiKit.heading("HQ & ARMORY", pal))
	col.add_child(UiKit.heading("ROSTER", pal, 52))
	for p in roster:
		col.add_child(_roster_card(p, pal))
	col.add_child(UiKit.heading("ARMORY", pal, 52))
	col.add_child(UiKit.caption("PvP standardized loadout budget: %d points." % armory.STANDARDIZED_LOADOUT_POINTS, pal))
	_add_category(col, pal, "WEAPONS", armory.WEAPONS)
	_add_category(col, pal, "ATTACHMENTS", armory.ATTACHMENTS)
	_add_category(col, pal, "ARMOR", armory.ARMOR_TIERS)
	_add_category(col, pal, "TACTICAL TOOLS", armory.TACTICAL_TOOLS)
	_add_category(col, pal, "DRONES", armory.DRONES)
	_add_category(col, pal, "VEHICLES", armory.VEHICLES)
	print("[TacPlan] screen=hq roster=%d" % roster.size())


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


func _add_category(col: VBoxContainer, pal: Dictionary, title: String, items: Array[StringName]) -> void:
	var unlocked := 0
	for item in items:
		if armory.is_unlocked(item):
			unlocked += 1
	col.add_child(UiKit.caption("%s  (%d / %d unlocked)" % [title, unlocked, items.size()], pal, false))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in items:
		var l := Label.new()
		l.text = item_label(item) + ("" if armory.is_unlocked(item) else "  [LOCKED]")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", pal["ink"] if armory.is_unlocked(item) else pal["muted"])
		grid.add_child(l)
	col.add_child(grid)


func _go_back() -> void:
	ScreenRouter.goto_stage(ScreenRouter.Stage.TITLE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if UiKit.is_back_event(event):
		_go_back()
