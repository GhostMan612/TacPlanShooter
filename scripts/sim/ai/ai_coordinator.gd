# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name AiCoordinator
extends RefCounted


var blackboard := ThreatBlackboard.new()
var enemies: Dictionary = {}


func step_all() -> void:
	for k in enemies.keys():
		var e: EnemyAi = enemies[k]
		e.suppress_tick_down()


func add_enemy(ai_id: int, archetype: StringName) -> void:
	var a := AiArchetypes.by_name(archetype)
	var e := EnemyAi.new()
	e.morale = int(a["base_morale"])
	enemies[ai_id] = e
