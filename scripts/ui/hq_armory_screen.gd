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


func draw_slot_cards() -> void:
	var x := 8.0
	for item in armory.WEAPONS:
		if armory.is_unlocked(item):
			draw_rect(Rect2(Vector2(x, 4.0), Vector2(72.0, 36.0)), Color(0.12, 0.18, 0.3))
			x += 84.0
