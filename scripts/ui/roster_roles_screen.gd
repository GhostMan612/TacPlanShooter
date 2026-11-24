# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name RosterRolesScreen
extends Control


var save := ProgressionSave.new()


func assign_role(profile: UnitProfile, role: int) -> void:
	profile.assign_role(role)


func promote(profile: UnitProfile) -> void:
	profile.assign_role(UnitProfile.Role.SQUAD_LEADER)


func record_xp(profile: UnitProfile, xp: int) -> void:
	profile.earn_xp(xp)
