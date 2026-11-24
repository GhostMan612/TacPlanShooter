# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name SquadCoordinator
extends RefCounted


enum Role { ANCHOR, SUPPRESSOR, FLANKER, RUNNER }


var role_of: Dictionary = {}
var sight_penalty: Dictionary = {}


func assign_role(ai_id: int, role: int) -> void:
	role_of[ai_id] = role


func role(ai_id: int) -> int:
	return int(role_of.get(ai_id, int(Role.ANCHOR)))


func set_sight_penalty(cell: Vector2i, penalty: int) -> void:
	sight_penalty[cell] = penalty


func sight_penalty_of(cell: Vector2i) -> int:
	return int(sight_penalty.get(cell, 0))
