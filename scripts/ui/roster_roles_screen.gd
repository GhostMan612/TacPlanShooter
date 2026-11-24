# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name RosterRolesScreen
extends Control


var save := ProgressionSave.new()
var portraits: Dictionary = {}


func bind_portraits() -> void:
	for n in [
		&"opr_01_vanguard", &"opr_02_vector", &"opr_03_sledge",
		&"opr_04_aegis", &"opr_05_specter", &"opr_06_lifeline",
	]:
		var p := "res://assets/portraits/" + str(n) + ".png"
		var tex: Texture2D = null if not ResourceLoader.exists(p) else (ResourceLoader.load(p, "Texture2D") as Texture2D)
		portraits[n] = tex


func assign_role(profile: UnitProfile, role: int) -> void:
	profile.assign_role(role)


func promote(profile: UnitProfile) -> void:
	profile.assign_role(UnitProfile.Role.SQUAD_LEADER)


func record_xp(profile: UnitProfile, xp: int) -> void:
	profile.earn_xp(xp)


func draw_bars() -> void:
	var y := 16.0
	for t in OperativeProfile.TRAIT_NAMES:
		draw_rect(Rect2(Vector2(8.0, y), Vector2(200.0, 10.0)), Color(0.08, 0.14, 0.22))
		draw_rect(Rect2(Vector2(8.0, y), Vector2(60.0, 10.0)), Color(0.2, 0.6, 0.95))
		y += 16.0
