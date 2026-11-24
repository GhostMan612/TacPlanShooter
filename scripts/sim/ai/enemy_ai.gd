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


func ai_tick() -> void:
	if surrender_check():
		transition(int(State.SURRENDER))
	elif suppression >= 80:
		transition(int(State.SUPPRESS_LKP))
	elif state == int(State.STUNNED) and suppression > 0:
		transition(int(State.TAKE_COVER))
	elif state == int(State.SUPPRESS_LKP):
		transition(int(State.INVESTIGATE_LKP))
	elif state == int(State.IDLE_GUARD) and suppression > 0:
		transition(int(State.HOLD_AMBUSH))
	elif state == int(State.HOLD_AMBUSH) and suppression < 10:
		transition(int(State.IDLE_GUARD))
