# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name UnitProfile
extends RefCounted


enum Role { SQUAD_LEADER, POINTMAN, BREACHER, SHIELD_HEAVY, TECH_DRONE_OPERATOR, MARKSMAN_OVERWATCH, MEDIC_RESCUE }


var operative_id := -1
var codename := &""
var xp := 0
var role := int(Role.POINTMAN)
var mission_ribbons: Array[StringName] = []
var equipped: Array[StringName] = []


func assign_role(role: int) -> void:
	self.role = role


func earn_xp(amount: int) -> void:
	xp += max(int(amount), 0)


func add_ribbon(name: StringName) -> void:
	mission_ribbons.append(name)


func equip(item: StringName) -> void:
	equipped.append(item)


func loadout_points() -> int:
	return equipped.size()


func to_dict() -> Dictionary:
	var ribs := []
	for r in mission_ribbons:
		ribs.append(String(r))
	var eq := []
	for e in equipped:
		eq.append(String(e))
	return {
		"operative_id": operative_id,
		"codename": String(codename),
		"xp": xp,
		"role": role,
		"mission_ribbons": ribs,
		"equipped": eq,
	}


static func from_dict(d: Dictionary) -> UnitProfile:
	var p := UnitProfile.new()
	p.operative_id = int(d.get("operative_id", -1))
	p.codename = StringName(String(d.get("codename", "")))
	p.xp = int(d.get("xp", 0))
	p.role = int(d.get("role", int(Role.POINTMAN)))
	for r in d.get("mission_ribbons", []):
		p.mission_ribbons.append(StringName(String(r)))
	for e in d.get("equipped", []):
		p.equipped.append(StringName(String(e)))
	return p
