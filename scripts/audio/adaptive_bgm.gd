# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name AdaptiveBgm
extends Node


enum State { PLANNING_STEALTH, CAUTION_INVESTIGATE, COMBAT_ALERT, AAR_VICTORY, AAR_DEFEAT }


var state := int(State.PLANNING_STEALTH)


func _ready() -> void:
	EventBus.breach_detonated.connect(_on_breach_detonated)
	EventBus.operative_damaged.connect(_on_operative_damaged)


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


func _on_breach_detonated(world_pos: Vector2) -> void:
	set_state(int(State.COMBAT_ALERT))


func _on_operative_damaged(operative_id: int, remaining_hp: int) -> void:
	if remaining_hp <= 20 and state != int(State.COMBAT_ALERT):
		set_state(int(State.COMBAT_ALERT))
