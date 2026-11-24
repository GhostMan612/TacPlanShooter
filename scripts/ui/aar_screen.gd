# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name AarScreen
extends Control


var world: SimWorld = null


func compute_grade() -> Dictionary:
	var g := MissionGrading.new()
	return g.grade(world, true)
