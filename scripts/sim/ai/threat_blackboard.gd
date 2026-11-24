# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name ThreatBlackboard
extends RefCounted


const FOCAL_ANGLE := 35.0
const PERIPHERAL_ANGLE := 75.0


var threats: Dictionary = {}
var acoustic: Array = []
var alert_level := 0


func set_threat(ai_id: int, target_id: int, lkp: Vector2) -> void:
	threats[ai_id] = {"target": target_id, "lkp": lkp}


func has_threat(ai_id: int) -> bool:
	return threats.has(ai_id)


func clear_threat(ai_id: int) -> void:
	threats.erase(ai_id)


func hearing_attenuation(walls: int) -> float:
	return -0.35 * float(walls)
