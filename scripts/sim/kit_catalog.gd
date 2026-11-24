# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name KitCatalog
extends RefCounted


const EQUIP_SLOT_COUNT := 2


const WEAPONS: Array[Dictionary] = [
	{"id": &"weapon_smg_standard", "suppressed": false, "penetration": 3},
	{"id": &"weapon_smg_suppressed", "suppressed": true, "penetration": 2},
	{"id": &"weapon_carbine_compact", "suppressed": false, "penetration": 5},
	{"id": &"weapon_rifle_ap", "suppressed": false, "penetration": 9},
	{"id": &"weapon_shotgun_breach", "suppressed": false, "penetration": 12},
	{"id": &"weapon_pistol_standard", "suppressed": false, "penetration": 4},
	{"id": &"weapon_pistol_suppressed", "suppressed": true, "penetration": 3},
]


const EQUIPMENT: Array[StringName] = [&"extra_primary_mag", &"extra_secondary_mag", &"frag_grenade", &"flashbang", &"heartbeat_sensor", &"lockpick_kit", &"electronics_kit", &"demolitions_kit"]


const ARMOR: Array[Dictionary] = [
	{"class": &"light", "quiet": 0.5, "protection": 1, "speed_mult": 1.2},
	{"class": &"medium", "quiet": 1.0, "protection": 2, "speed_mult": 0.9},
	{"class": &"heavy", "quiet": 1.6, "protection": 3, "speed_mult": 0.7},
]


static func get_weapon(id: StringName) -> Dictionary:
	for w in WEAPONS:
		if w["id"] == id:
			return w
	return {"id": &"", "suppressed": false, "penetration": 0}


static func get_armor(class_id: StringName) -> Dictionary:
	for a in ARMOR:
		if a["class"] == class_id:
			return a
	return {"class": &"light", "quiet": 0.5, "protection": 1, "speed_mult": 1.2}
