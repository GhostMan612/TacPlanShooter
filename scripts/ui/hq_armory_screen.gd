# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name ArmoryScreen
extends Control


var armory := ArmoryCatalog.new()


func try_equip(profile: UnitProfile, item: StringName) -> bool:
	if not armory.is_unlocked(item):
		return false
	profile.equip(item)
	return true


func valid_for_pvp(profile: UnitProfile) -> bool:
	return profile.loadout_points() <= armory.STANDARDIZED_LOADOUT_POINTS
