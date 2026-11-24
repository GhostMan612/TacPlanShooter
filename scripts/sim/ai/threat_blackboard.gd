# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name ThreatBlackboard
extends RefCounted


const FOCAL_ANGLE := 35.0
const PERIPHERAL_ANGLE := 75.0


enum Alert { UNAWARE, ALERTED, COMBAT }


var threats: Dictionary = {}
var alerts: Dictionary = {}
var acoustic: Array = []
var alert_level := int(Alert.UNAWARE)


func set_threat(ai_id: int, target_id: int, lkp: Vector2) -> void:
	threats[ai_id] = {"target": target_id, "lkp": lkp}


func set_alert(ai_id: int, level: int) -> void:
	alerts[ai_id] = level


func escalate(ai_id: int) -> void:
	var cur := int(alerts.get(ai_id, int(Alert.UNAWARE)))
	if cur < int(Alert.COMBAT):
		alerts[ai_id] = cur + 1
		if cur + 1 > alert_level:
			alert_level = cur + 1


func has_threat(ai_id: int) -> bool:
	return threats.has(ai_id)


func clear_threat(ai_id: int) -> void:
	threats.erase(ai_id)


func lkp_of(ai_id: int) -> Vector2:
	if threats.has(ai_id):
		var e: Dictionary = threats[ai_id]
		return Vector2(e["lkp"])
	return Vector2.ZERO


func target_of(ai_id: int) -> int:
	if threats.has(ai_id):
		var e: Dictionary = threats[ai_id]
		return int(e["target"])
	return -1


func hearing_attenuation(walls: int) -> float:
	return -0.35 * float(walls)
