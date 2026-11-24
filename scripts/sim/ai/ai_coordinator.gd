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
		if e.suppression > 0:
			e.ai_tick()


func add_enemy(ai_id: int, archetype: StringName) -> void:
	var a := AiArchetypes.by_name(archetype)
	var e := EnemyAi.new()
	e.morale = int(a["base_morale"])
	enemies[ai_id] = e


func update_threats(world: SimWorld) -> void:
	var segs := world.map.get_wall_segments()
	for k in enemies.keys():
		var op := _ai_op(world, k)
		if op == null:
			continue
		var seen := false
		for t in world.operates:
			if not t.is_alive():
				continue
			if blackboard.cone_visible(op.pos, t.pos, op.facing_deg, true, segs):
				blackboard.set_threat(k, t.id, t.pos)
				seen = true
			elif blackboard.has_threat(k) and blackboard.target_of(k) == t.id:
				blackboard.escalate(k)
		if not seen and not blackboard.has_threat(k):
			blackboard.clear_threat(k)


func _ai_op(world: SimWorld, ai_id: int) -> SimOperative:
	for o in world.operates:
		if o.id == ai_id:
			return o
	return null
