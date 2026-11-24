# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name IconRegistry
extends RefCounted


const ICONS: Array[StringName] = [
	&"stance_blitz", &"stance_normal", &"stance_cautious",
	&"roe_engage", &"roe_advance", &"roe_escort",
	&"code_alpha", &"code_bravo", &"code_charlie", &"code_delta",
	&"action_flashbang", &"action_frag", &"action_tear_gas", &"action_breach",
	&"action_lockpick", &"action_fof",
	&"role_squad_leader", &"role_pointman", &"role_breacher", &"role_shield",
	&"role_tech_drone_operator", &"role_marksman_overwatch", &"role_medic_rescue",
	&"equipment_mag_p", &"equipment_mag_s", &"equipment_frag", &"equipment_flashbang",
	&"equipment_heartbeat", &"equipment_lockpick", &"equipment_electronics", &"equipment_demolitions",
	&"item_drone_ground", &"item_drone_uav", &"item_vehicle_van", &"item_vehicle_apc",
	&"objective_hostage", &"objective_bomb", &"objective_intel", &"objective_hvt", &"objective_extract",
]


static func is_icon(name: StringName) -> bool:
	for i in ICONS:
		if i == name:
			return true
	return false


static func count() -> int:
	return ICONS.size()
