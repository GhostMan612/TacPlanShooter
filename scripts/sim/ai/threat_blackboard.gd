# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name ThreatBlackboard
extends RefCounted


const FOCAL_ANGLE := 35.0
const PERIPHERAL_ANGLE := 75.0
const FOCAL_MAX_RANGE := 100.0
const PERIPHERAL_RANGE_MULT := 0.6


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


func cone_visible(observer: Vector2, target: Vector2, facing_deg: float, focal: bool, segs: Array) -> bool:
	var d := target - observer
	if d.length_squared() < 0.0001:
		return true
	var dist := d.length()
	var rel := wrapf(atan2(d.y, d.x) - facing_deg * PI / 180.0, -PI, PI)
	var limit := FOCAL_ANGLE if focal else PERIPHERAL_ANGLE
	if abs(rel) > limit * PI / 180.0:
		return false
	if focal and dist > FOCAL_MAX_RANGE:
		return false
	if not focal and dist > FOCAL_MAX_RANGE * PERIPHERAL_RANGE_MULT:
		return false
	for s in segs:
		if Visibility._ray_hit_t(observer, d, s[0], s[1]) > 0.000001:
			return false
	return true
