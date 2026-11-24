# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name BallisticsSuppression
extends RefCounted


enum Armor { LIGHT_IIA, MEDIUM_II, HEAVY_III_IV, SHIELD }
enum Medical { HEALTHY, WOUNDED, INCAPACITATED, KIA }


const ARMOR_TABLE: Dictionary = {
	&"light_iia": 2,
	&"medium_ii": 4,
	&"heavy_iii_iv": 8,
	&"shield": 3,
}


const CALIBERS: Array[Dictionary] = [
	{"name": &"9mm", "pen": 3},
	{"name": &"5.56", "pen": 6},
	{"name": &"7.62", "pen": 9},
]


var suppression: Dictionary = {}


func damage_for(caliber: StringName, armor: StringName) -> int:
	var pen := 0
	for c in CALIBERS:
		if c["name"] == caliber:
			pen = int(c["pen"])
	if pen <= 0:
		return 0
	return max(pen - int(ARMOR_TABLE.get(armor, 0)), 1)


func apply_suppression(op_id: int, ticks: int) -> void:
	suppression[op_id] = ticks


func suppressed_ticks(op_id: int) -> int:
	return int(suppression.get(op_id, 0))


func medical_state(health: StringName) -> int:
	if health == &"wounded":
		return int(Medical.WOUNDED)
	if health == &"incapacitated":
		return int(Medical.INCAPACITATED)
	if health == &"kia":
		return int(Medical.KIA)
	return int(Medical.HEALTHY)
