# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name AdaptiveBgm
extends Node


enum State { PLANNING_STEALTH, CAUTION_INVESTIGATE, COMBAT_ALERT, AAR_VICTORY, AAR_DEFEAT }


var state := int(State.PLANNING_STEALTH)


func set_state(s: int) -> void:
	state = s


func is_alert() -> bool:
	return state == int(State.COMBAT_ALERT)


func apply() -> void:
	match state:
		State.AAR_VICTORY:
			pass
		State.AAR_DEFEAT:
			pass
		State.COMBAT_ALERT:
			pass
		State.CAUTION_INVESTIGATE:
			pass
		State.PLANNING_STEALTH:
			pass
