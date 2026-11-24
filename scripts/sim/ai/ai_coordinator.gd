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
	if enemies.is_empty():
		return
	var segs := world.map.get_wall_segments()
	for id in enemies:
		var observer: SimOperative = world.enemy_actors.get(id)
		if observer == null or not observer.is_alive():
			blackboard.clear_threat(id)
			continue
		for target in world.operatives:
			if not target.is_alive() or target.faction_id == observer.faction_id:
				continue
			if blackboard.cone_visible(observer.pos, target.pos, observer.facing_deg, true, segs):
				blackboard.set_threat(id, target.id, target.pos)
			elif blackboard.target_of(id) == target.id:
				blackboard.escalate(id)


func acoustic_rings() -> Array:
	var rings := []
	for e in blackboard.acoustic:
		var kind := String(e["kind"])
		if kind == &"gunshot_unsuppressed" or kind == &"sprint":
			rings.append({"cell": e["cell"], "tick": int(e["t"])})
	return rings


func to_dict() -> Dictionary:
	var enemy_states := {}
	for id in enemies:
		var enemy: EnemyAi = enemies[id]
		enemy_states[str(id)] = {
			"state": enemy.state,
			"suppression": enemy.suppression,
			"morale": enemy.morale,
		}
	return {"blackboard": blackboard.to_dict(), "enemies": enemy_states}


static func from_dict(d: Dictionary) -> AiCoordinator:
	var coordinator := AiCoordinator.new()
	coordinator.blackboard = ThreatBlackboard.from_dict(d.get("blackboard", {}))
	var enemy_states: Dictionary = d.get("enemies", {})
	for id in enemy_states:
		var state: Dictionary = enemy_states[id]
		var enemy := EnemyAi.new()
		enemy.state = int(state["state"])
		enemy.suppression = int(state["suppression"])
		enemy.morale = int(state["morale"])
		coordinator.enemies[int(id)] = enemy
	return coordinator
