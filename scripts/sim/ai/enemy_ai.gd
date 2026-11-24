# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name EnemyAi
extends RefCounted


enum State { IDLE_GUARD, PATROL, INVESTIGATE_LKP, HOLD_AMBUSH, SUPPRESS_LKP, FLANK_ROUTE, TAKE_COVER, STUNNED, FALLBACK_RALLY, HOSTAGE_COERCE, SURRENDER }


var state := int(State.IDLE_GUARD)
var suppression := 0
var morale := 50


func transition(s: int) -> void:
	state = s


func suppress_near_miss(ticks: int) -> void:
	suppression += ticks


func suppress_tick_down() -> void:
	if suppression > 0:
		suppression -= 1


func surrender_check() -> bool:
	return state == int(State.SUPPRESS_LKP) and suppression >= 80 and morale <= 20


func is_stunned() -> bool:
	return state == int(State.STUNNED)
