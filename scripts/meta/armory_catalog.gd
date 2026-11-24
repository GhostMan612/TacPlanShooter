# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name ArmoryCatalog
extends RefCounted


const STANDARDIZED_LOADOUT_POINTS: int = 12


const WEAPONS: Array[StringName] = [&"weapon_smg_standard", &"weapon_smg_suppressed", &"weapon_carbine_compact", &"weapon_rifle_ap", &"weapon_shotgun_breach", &"weapon_pistol_standard", &"weapon_pistol_suppressed"]


const ATTACHMENTS: Array[StringName] = [&"attachment_suppressor", &"attachment_optic", &"attachment_laser", &"attachment_ap_ammo", &"attachment_subsonic_ammo"]


const ARMOR_TIERS: Array[StringName] = [&"armor_light_iia", &"armor_medium_ii", &"armor_heavy_iii_iv", &"armor_shield"]


const TACTICAL_TOOLS: Array[StringName] = [&"tool_underdoor_cam", &"tool_lockpick", &"tool_electronics", &"tool_demolitions", &"tool_heartbeat_sensor", &"tool_ifak", &"tool_jammer"]


const DRONES: Array[StringName] = [&"drone_ground_recon", &"drone_micro_uav", &"drone_utility"]


const VEHICLES: Array[StringName] = [&"vehicle_raid_van", &"vehicle_apc", &"vehicle_extraction_suv"]


var unlocked: Dictionary = {}


func is_unlocked(item: StringName) -> bool:
	return unlocked.has(item)


func unlock(item: StringName) -> void:
	unlocked[item] = true
