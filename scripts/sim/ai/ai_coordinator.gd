# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name AiCoordinator
extends RefCounted

var blackboard := ThreatBlackboard.new()
var enemies: Dictionary = {}
var influence := InfluenceMap.new()
var tactics := SquadTactics.new()
var commander := CpuCommander.new()
var squad := SquadCoordinator.new()
var last_acoustic_idx: int = 0


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
	e.configure(archetype, commander.doctrine)
	enemies[ai_id] = e


func update_threats(world: SimWorld, segs_override: Array = []) -> void:
	if enemies.is_empty():
		return
	var segs_by_floor: Dictionary = {}
	var ids: Array = enemies.keys()
	ids.sort()
	for id in ids:
		var observer: SimOperative = world.enemy_actors.get(id)
		if observer == null or not observer.is_alive():
			blackboard.clear_threat(id)
			continue
		var segs: Array
		if not segs_override.is_empty():
			segs = segs_override
		else:
			if not segs_by_floor.has(observer.floor_idx):
				segs_by_floor[observer.floor_idx] = world.map_on_floor(observer.floor_idx).get_wall_segments()
			segs = segs_by_floor[observer.floor_idx]
		var brain: EnemyAi = enemies[id]
		var saw_any := false
		for target in world.operatives:
			if not target.is_alive() or target.faction_id == observer.faction_id or target.floor_idx != observer.floor_idx:
				continue
			var tcell: Vector2i = GridUtil.cell_of(target.pos)
			if influence.is_smoked(tcell) or influence.is_smoked(GridUtil.cell_of(observer.pos)):
				continue
			if blackboard.cone_visible(observer.pos, target.pos, observer.facing_deg, true, segs):
				var prev_target: int = blackboard.target_of(id)
				blackboard.set_threat(id, target.id, target.pos)
				blackboard.set_alert(id, int(ThreatBlackboard.Alert.COMBAT))
				if int(ThreatBlackboard.Alert.COMBAT) > blackboard.alert_level:
					blackboard.alert_level = int(ThreatBlackboard.Alert.COMBAT)
				if prev_target != target.id:
					tactics.emit_callout(world.journal, world.tick, id, "CONTACT_VISUAL", tcell)
				saw_any = true
				break
			elif blackboard.target_of(id) == target.id:
				blackboard.escalate(id)
		if not saw_any:
			var prev_id: int = blackboard.target_of(id)
			if prev_id >= 0:
				blackboard.escalate(id)
		for d in world.drones:
			if d.destroyed or d.signal_strength <= 0 or observer.floor_idx != 0:
				continue
			if d.pos.distance_to(observer.pos) <= 7.0 and CombatSystem.line_clear(d.pos, observer.pos, segs):
				if brain.spotted_by_drone_id != d.id:
					brain.spotted_by_drone_id = d.id
					brain.spotted_cell = GridUtil.cell_of(observer.pos)
				break


func step_world(world: SimWorld) -> void:
	tactics.tick_down()
	var ids: Array = enemies.keys()
	ids.sort()
	for id in ids:
		var brain: EnemyAi = enemies[id]
		brain.suppress_tick_down()
		if brain.stun_ticks > 0:
			brain.stun_ticks -= 1
			if brain.stun_ticks == 0 and brain.state == int(EnemyAi.State.STUNNED):
				brain.transition(int(EnemyAi.State.TAKE_COVER))
		if brain.reload_ticks_left > 0:
			brain.reload_ticks_left -= 1
			if brain.reload_ticks_left == 0:
				brain.ammo = brain.mag_size
		if brain.grenade_cooldown > 0:
			brain.grenade_cooldown -= 1
		if brain.suppression > 0:
			brain.ai_tick()
	influence.ensure_size(world.map)
	influence.clear_dynamic(world.tick)
	var segs_by_floor: Dictionary = {0: world.map.get_wall_segments()}
	update_threats(world, [])
	_ingest_acoustic_events(world)
	_refresh_influence_danger(world, segs_by_floor[0])
	commander.step_commander(world)
	var shared_lkp := _first_known_lkp(ids)
	if shared_lkp != Vector2(-1.0, -1.0):
		tactics.assign_bounding_roles(world.map, world.enemy_actors, enemies, squad, shared_lkp, influence, segs_by_floor[0])
	var any_suppressing := false
	for id in ids:
		var b: EnemyAi = enemies[id]
		if b.ally_suppressing:
			any_suppressing = true
			break
	for id in ids:
		var actor: SimOperative = world.enemy_actors.get(id)
		var brain: EnemyAi = enemies[id]
		if actor == null or not actor.is_alive():
			continue
		if brain.is_stunned() or brain.state == int(EnemyAi.State.SURRENDER):
			continue
		if not segs_by_floor.has(actor.floor_idx):
			segs_by_floor[actor.floor_idx] = world.map_on_floor(actor.floor_idx).get_wall_segments()
		_step_enemy_brain(world, actor, brain, any_suppressing, segs_by_floor[actor.floor_idx])


func _ingest_acoustic_events(world: SimWorld) -> void:
	var count: int = blackboard.acoustic.size()
	var ids: Array = enemies.keys()
	ids.sort()
	for i in range(last_acoustic_idx, count):
		var ev: Dictionary = blackboard.acoustic[i]
		var ev_cell: Vector2i = ev["cell"]
		var kind: StringName = StringName(String(ev.get("kind", "")))
		var ev_pos := Vector2(float(ev_cell.x) + 0.5, float(ev_cell.y) + 0.5)
		for id in ids:
			var actor: SimOperative = world.enemy_actors.get(id)
			if actor == null or not actor.is_alive():
				continue
			var brain: EnemyAi = enemies[id]
			if kind == &"door_breach":
				if actor.pos.distance_to(ev_pos) <= 14.0:
					brain.heard_breach_cell = ev_cell
					blackboard.escalate(id)
			elif kind == &"gunshot_unsuppressed":
				var dist: float = actor.pos.distance_to(ev_pos)
				if dist <= 12.0 and not blackboard.has_threat(id):
					var is_enemy_shot := false
					for op in world.operatives:
						if op.is_alive() and GridUtil.cell_of(op.pos) == ev_cell:
							is_enemy_shot = true
							blackboard.set_threat(id, op.id, op.pos)
							break
					if not is_enemy_shot:
						blackboard.escalate(id)
	last_acoustic_idx = count


func _refresh_influence_danger(world: SimWorld, segs: Array) -> void:
	for id in enemies.keys():
		if not blackboard.has_threat(id):
			continue
		var t_id: int = blackboard.target_of(id)
		var lkp: Vector2 = blackboard.lkp_of(id)
		var actor: SimOperative = world.enemy_actors.get(id)
		if actor == null:
			continue
		var facing: float = CombatSystem.angle_to(lkp, actor.pos)
		for op in world.operatives:
			if op.id == t_id and op.is_alive():
				if CombatSystem.line_clear(actor.pos, op.pos, segs):
					facing = op.facing_deg
				break
		influence.stamp_cone_danger(world.map, lkp, facing, CombatSystem.ENGAGE_RANGE_CELLS, CombatSystem.ENGAGE_HALF_ANGLE_DEG, 90, segs)


func _first_known_lkp(ids: Array) -> Vector2:
	for id in ids:
		if blackboard.has_threat(id):
			return blackboard.lkp_of(id)
	return Vector2(-1.0, -1.0)


func _step_enemy_brain(world: SimWorld, actor: SimOperative, brain: EnemyAi, any_suppressing: bool, segs: Array) -> void:
	var cfg: Dictionary = SquadTactics.doctrine_config(brain.doctrine)
	var max_depth: int = int(cfg.get("max_goap_depth", 4))
	var allow_grenades: bool = bool(cfg.get("allow_grenades", true))
	var allow_smoke: bool = bool(cfg.get("allow_smoke", true))
	var facts: Dictionary = _build_facts(world, actor, brain, any_suppressing, segs)
	var mask: int = GoapActions.facts_to_mask(facts)
	var role: int = squad.role(actor.id)
	var urgent: bool = false
	if brain.spotted_by_drone_id >= 0 and brain.goap_goal != &"anti_drone":
		urgent = true
	elif brain.ammo <= EnemyAi.LOW_AMMO_THRESHOLD and brain.goap_goal != &"tactical_reload":
		urgent = true
	elif brain.heard_breach_cell != Vector2i(-1, -1) and not bool(facts["target_visible"]) and brain.goap_goal != &"breach_counter":
		urgent = true
	elif brain.goap_plan.is_empty() and (bool(facts["target_visible"]) or bool(facts["lkp_known"]) or bool(facts["under_suppression"])):
		urgent = true
	var lock_flush_advance: bool = (
		brain.goap_goal == &"flush_cover"
		and brain.goap_index < brain.goap_plan.size()
		and brain.goap_plan[brain.goap_index] == &"AdvanceOnStunned"
		and brain.spotted_by_drone_id < 0
		and brain.ammo > EnemyAi.LOW_AMMO_THRESHOLD
	)
	if not lock_flush_advance and (urgent or GoapPlanner.should_replan(world.tick, actor.id)):
		var res: Dictionary = GoapPlanner.plan_for_unit(mask, role, max_depth, allow_grenades, allow_smoke)
		var new_goal: StringName = res["goal"]
		var new_plan: Array[StringName] = res["actions"]
		var keep_progress: bool = (new_goal == brain.goap_goal and brain.goap_index < brain.goap_plan.size())
		if not keep_progress:
			brain.goap_goal = new_goal
			brain.goap_plan = new_plan
			brain.goap_index = 0
			actor.active_path = PackedVector2Array()
			actor.path_index = 0
			if not new_plan.is_empty():
				world.journal.append({"t": world.tick, "ev": &"goap_plan", "op": actor.id, "goal": String(new_goal), "steps": new_plan.size()})
	if brain.goap_index < brain.goap_plan.size():
		var prev_idx: int = brain.goap_index
		_execute_goap_action(world, actor, brain, facts, segs)
		if brain.goap_index != prev_idx:
			actor.active_path = PackedVector2Array()
			actor.path_index = 0
	elif actor.queue != null and not actor.queue.is_complete():
		_step_enemy_queue(world, actor)


func _build_facts(world: SimWorld, actor: SimOperative, brain: EnemyAi, any_suppressing: bool, segs: Array) -> Dictionary:
	var actor_cell: Vector2i = GridUtil.cell_of(actor.pos)
	var has_lkp: bool = blackboard.has_threat(actor.id)
	var lkp_pos: Vector2 = blackboard.lkp_of(actor.id) if has_lkp else Vector2.ZERO
	var lkp_cell: Vector2i = GridUtil.cell_of(lkp_pos)
	var target_vis := false
	if has_lkp:
		var t_id: int = blackboard.target_of(actor.id)
		for op in world.operatives:
			if op.id == t_id and op.is_alive():
				target_vis = blackboard.cone_visible(actor.pos, op.pos, actor.facing_deg, true, segs)
				break
	var fmap := world.map_on_floor(actor.floor_idx)
	var in_cover := false
	if has_lkp:
		in_cover = influence.is_hard_cover_from(fmap, actor_cell, lkp_pos, segs)
	var under_sup: bool = world.ballistics.suppressed_ticks(actor.id) > 0 or brain.suppression >= 30
	var ammo_low: bool = brain.ammo <= EnemyAi.LOW_AMMO_THRESHOLD
	var hostage_near := false
	if has_lkp:
		for hs in fmap.hostage_spawns:
			var hc: Vector2i = CpuCommander._cell_from_entry(hs)
			if absi(hc.x - lkp_cell.x) + absi(hc.y - lkp_cell.y) <= 3:
				hostage_near = true
				break
	var target_in_cover := false
	if has_lkp and not target_vis:
		target_in_cover = true
	var throw_ready := false
	if has_lkp and (brain.has_flashbang or brain.has_frag):
		throw_ready = influence.pick_grenade_landing_cell(fmap, actor.pos, lkp_cell, float(SimConstants.ACTION_MAX_RANGE_CELLS), segs) != InfluenceMap.NO_CELL
	var drone_shootable := false
	if brain.spotted_by_drone_id >= 0:
		var d: SimDrone = _find_drone(world, brain.spotted_by_drone_id)
		if d != null and not d.destroyed and d.pos.distance_to(actor.pos) <= CombatSystem.ENGAGE_RANGE_CELLS and CombatSystem.line_clear(actor.pos, d.pos, segs):
			drone_shootable = true
	var flank_open := false
	if has_lkp and squad.role(actor.id) == int(SquadCoordinator.Role.FLANKER) and tactics.flank_target_cell != Vector2i(-1, -1):
		flank_open = true
	return {
		"target_visible": target_vis,
		"lkp_known": has_lkp,
		"in_cover": in_cover,
		"under_suppression": under_sup,
		"ammo_low": ammo_low,
		"ammo_full": not ammo_low,
		"has_flashbang": brain.has_flashbang and brain.grenade_cooldown == 0,
		"has_frag": brain.has_frag and brain.grenade_cooldown == 0,
		"has_smoke": brain.has_smoke and brain.grenade_cooldown == 0,
		"ally_suppressing": any_suppressing or brain.ally_suppressing,
		"flank_open": flank_open,
		"spotted_by_drone": brain.spotted_by_drone_id >= 0,
		"hostage_near": hostage_near,
		"target_in_cover": target_in_cover,
		"has_throw_angle": throw_ready,
		"hear_breach": brain.heard_breach_cell != Vector2i(-1, -1),
		"jammer_available": commander.is_jammer_near(actor_cell, 6),
		"drone_shootable": drone_shootable,
	}


func _execute_goap_action(world: SimWorld, actor: SimOperative, brain: EnemyAi, facts: Dictionary, segs: Array) -> void:
	var fmap := world.map_on_floor(actor.floor_idx)
	var action: StringName = brain.goap_plan[brain.goap_index]
	var actor_cell: Vector2i = GridUtil.cell_of(actor.pos)
	var lkp_pos: Vector2 = blackboard.lkp_of(actor.id) if blackboard.has_threat(actor.id) else actor.pos + Vector2.RIGHT
	var lkp_cell: Vector2i = GridUtil.cell_of(lkp_pos)
	if action == &"CalloutCoveringFire":
		tactics.emit_callout(world.journal, world.tick, actor.id, "RELOADING_COVER_ME", actor_cell)
		brain.goap_index += 1
	elif action == &"StepBehindHardCover" or action == &"TakeHardCover":
		if influence.is_hard_cover_from(fmap, actor_cell, lkp_pos, segs):
			brain.target_cell = Vector2i(-1, -1)
			brain.goap_index += 1
			return
		if brain.target_cell == Vector2i(-1, -1):
			brain.target_cell = influence.best_cover_cell(fmap, actor_cell, lkp_pos, 6, {}, true, segs)
		if brain.target_cell == Vector2i(-1, -1):
			brain.target_cell = influence.best_cover_cell(fmap, actor_cell, lkp_pos, 6, {}, false, segs)
		if brain.target_cell == Vector2i(-1, -1):
			brain.goap_index += 1
			return
		if _follow_tactical_path(world, actor, brain.target_cell, 1):
			brain.target_cell = Vector2i(-1, -1)
			brain.goap_index += 1
	elif action == &"Reload":
		if brain.reload_ticks_left == 0 and brain.ammo <= EnemyAi.LOW_AMMO_THRESHOLD:
			brain.reload_ticks_left = EnemyAi.RELOAD_DURATION_TICKS
		elif brain.ammo > EnemyAi.LOW_AMMO_THRESHOLD:
			brain.goap_index += 1
	elif action == &"RePeek":
		if brain.peek_cell == Vector2i(-1, -1):
			brain.peek_cell = influence.best_peek_cell(fmap, actor_cell, lkp_pos, {}, segs)
		if brain.peek_cell != Vector2i(-1, -1):
			if _follow_tactical_path(world, actor, brain.peek_cell, 1):
				actor.facing_deg = CombatSystem.angle_to(actor.pos, lkp_pos)
				brain.peek_cell = Vector2i(-1, -1)
				brain.goap_index += 1
		else:
			actor.facing_deg = CombatSystem.angle_to(actor.pos, lkp_pos)
			brain.goap_index += 1
	elif action == &"MoveToThrowAngle":
		if influence.pick_grenade_landing_cell(fmap, actor.pos, lkp_cell, float(SimConstants.ACTION_MAX_RANGE_CELLS), segs) != InfluenceMap.NO_CELL:
			brain.target_cell = Vector2i(-1, -1)
			brain.goap_index += 1
			return
		if brain.target_cell == Vector2i(-1, -1):
			brain.target_cell = influence.best_throw_cell(fmap, actor_cell, lkp_cell, float(SimConstants.ACTION_MAX_RANGE_CELLS), 8, {}, segs)
		if brain.target_cell == Vector2i(-1, -1):
			brain.goap_index += 1
			return
		if _follow_tactical_path(world, actor, brain.target_cell, 1):
			brain.target_cell = Vector2i(-1, -1)
			brain.goap_index += 1
	elif action == &"ThrowFragOrFlash":
		var landing: Vector2i = influence.pick_grenade_landing_cell(fmap, actor.pos, lkp_cell, float(SimConstants.ACTION_MAX_RANGE_CELLS), segs)
		if landing == InfluenceMap.NO_CELL:
			brain.goap_index += 1
			return
		var kind: int = int(AgentCommand.ActionKind.FLASHBANG)
		if brain.has_flashbang:
			brain.has_flashbang = false
		elif brain.has_frag and not bool(facts["hostage_near"]):
			kind = int(AgentCommand.ActionKind.FRAG)
			brain.has_frag = false
		else:
			brain.goap_index += 1
			return
		var e := SimEntity.new()
		e.id = world.entity_seq
		e.kind = kind
		e.op_id = actor.id
		e.pos = Vector2(landing) + Vector2(0.5, 0.5)
		e.floor_idx = actor.floor_idx
		e.spawned_tick = world.tick
		e.due_tick = world.tick + 18
		world.entities.append(e)
		world.entity_seq += 1
		brain.grenade_cooldown = 90
		world.journal.append({"t": world.tick, "ev": &"entity_spawned", "id": e.id, "op": actor.id, "kind": e.kind, "tx": landing.x, "ty": landing.y})
		tactics.emit_callout(world.journal, world.tick, actor.id, "FLASH_OUT", landing)
		brain.goap_index += 1
	elif action == &"AdvanceOnStunned":
		var waiting_blast := false
		for ent in world.entities:
			if ent.op_id == actor.id and not ent.done:
				waiting_blast = true
				break
		if waiting_blast:
			return
		if _follow_tactical_path(world, actor, lkp_cell, 1) or CombatSystem.line_clear(actor.pos, lkp_pos, segs):
			actor.facing_deg = CombatSystem.angle_to(actor.pos, lkp_pos)
			brain.goap_index += 1
	elif action == &"SuppressLKP":
		actor.facing_deg = CombatSystem.angle_to(actor.pos, lkp_pos)
		brain.ally_suppressing = true
		tactics.emit_callout(world.journal, world.tick, actor.id, "SUPPRESSING", lkp_cell)
		if bool(facts["target_visible"]):
			brain.goap_index += 1
		elif not world.combat.fire_cooldowns.has(actor.id) and brain.ammo > 0:
			world.combat.fire_cooldowns[actor.id] = CombatSystem.FIRE_INTERVAL_TICKS
			brain.ammo = maxi(brain.ammo - 1, 0)
			world.sound_event(actor_cell, &"gunshot_unsuppressed")
			influence.stamp_lane_danger(fmap, actor.pos, lkp_pos, 40, segs)
			for op in world.operatives:
				if op.is_alive() and op.floor_idx == actor.floor_idx and op.pos.distance_to(lkp_pos) <= 2.0 and CombatSystem.line_clear(actor.pos, op.pos, segs):
					world.ballistics.apply_suppression(op.id, CombatSystem.SUPPRESS_TICKS)
	elif action == &"DeploySmoke":
		var se := SimEntity.new()
		se.id = world.entity_seq
		se.kind = int(AgentCommand.ActionKind.TEAR_GAS)
		se.op_id = actor.id
		se.pos = actor.pos
		se.floor_idx = actor.floor_idx
		se.spawned_tick = world.tick
		se.due_tick = world.tick + 1
		world.entities.append(se)
		world.entity_seq += 1
		brain.has_smoke = false
		brain.grenade_cooldown = 90
		brain.goap_index += 1
	elif action == &"BoundCoverToCover":
		var goal: Vector2i = tactics.flank_target_cell
		if goal == Vector2i(-1, -1):
			goal = SquadTactics.pick_flank_goal(fmap, actor_cell, lkp_pos, influence, segs)
		if goal == Vector2i(-1, -1):
			brain.goap_index += 1
			return
		var dir_label := "FLANKING_LEFT" if goal.y < actor_cell.y else "FLANKING_RIGHT"
		tactics.emit_callout(world.journal, world.tick, actor.id, dir_label, goal)
		if _follow_tactical_path(world, actor, goal, 2):
			brain.goap_index += 1
	elif action == &"FlankEngage":
		actor.facing_deg = CombatSystem.angle_to(actor.pos, lkp_pos)
		brain.goap_index += 1
	elif action == &"TriggerRFJammer":
		var jd: SimDrone = _find_drone(world, brain.spotted_by_drone_id)
		tactics.emit_callout(world.journal, world.tick, actor.id, "DRONE_SPOTTED", actor_cell)
		if jd != null and not jd.destroyed:
			jd.signal_strength = 0
			jd.destroyed = true
			world.journal.append({"t": world.tick, "ev": &"drone_jammed", "op": actor.id, "drone": jd.id})
		brain.goap_index += 1
	elif action == &"EngageDrone":
		var sd: SimDrone = _find_drone(world, brain.spotted_by_drone_id)
		tactics.emit_callout(world.journal, world.tick, actor.id, "DRONE_SPOTTED", actor_cell)
		if sd != null and not sd.destroyed:
			actor.facing_deg = CombatSystem.angle_to(actor.pos, sd.pos)
			brain.ammo = maxi(brain.ammo - 1, 0)
			sd.destroyed = true
			world.journal.append({"t": world.tick, "ev": &"drone_destroyed", "op": actor.id, "drone": sd.id})
		brain.goap_index += 1
	elif action == &"BreakDroneLOS":
		tactics.emit_callout(world.journal, world.tick, actor.id, "DRONE_SPOTTED", actor_cell)
		brain.goap_index += 1
	elif action == &"RepositionCell":
		if brain.target_cell == Vector2i(-1, -1) or brain.target_cell == brain.spotted_cell:
			brain.target_cell = _pick_reposition_cell(world, actor_cell, brain.spotted_cell, segs)
		if brain.target_cell == Vector2i(-1, -1):
			brain.spotted_by_drone_id = -1
			brain.goap_index += 1
			return
		if _follow_tactical_path(world, actor, brain.target_cell, 1):
			brain.spotted_by_drone_id = -1
			brain.spotted_cell = Vector2i(-1, -1)
			brain.target_cell = Vector2i(-1, -1)
			brain.goap_index += 1
	elif action == &"FallbackToCrossfireCell":
		if brain.target_cell == Vector2i(-1, -1):
			var claimed: Dictionary = {}
			var cf: Array[Dictionary] = SquadTactics.assign_crossfire_cells(fmap, brain.heard_breach_cell, Vector2i(1, 0), 1, claimed, segs)
			if not cf.is_empty():
				brain.target_cell = cf[0]["cell"]
		if brain.target_cell == Vector2i(-1, -1):
			brain.goap_index += 1
			return
		if _follow_tactical_path(world, actor, brain.target_cell, 1):
			brain.target_cell = Vector2i(-1, -1)
			brain.goap_index += 1
	elif action == &"PreAimFatalFunnel":
		var b_center := Vector2(brain.heard_breach_cell) + Vector2(0.5, 0.5)
		actor.facing_deg = CombatSystem.angle_to(actor.pos, b_center)
		actor.field_of_fire_deg = int(round(actor.facing_deg))
		brain.heard_breach_cell = Vector2i(-1, -1)
		brain.goap_index += 1
	elif action == &"EngageVisibleTarget":
		if blackboard.has_threat(actor.id):
			actor.facing_deg = CombatSystem.angle_to(actor.pos, lkp_pos)


func _step_enemy_queue(world: SimWorld, actor: SimOperative) -> void:
	if actor.cooldown_ticks > 0:
		actor.cooldown_ticks -= 1
		return
	if actor.wait_code != &"":
		if not world.go_codes_issued.has(actor.wait_code) and not commander.has_go_code(actor.wait_code):
			return
		actor.wait_code = &""
		actor.queue.advance_cursor()
	while true:
		var cmd: AgentCommand = actor.queue.peek_next()
		if cmd == null:
			actor.done = true
			return
		if cmd.command_type == AgentCommand.CommandType.SET_STANCE:
			actor.stance = cmd.stance_name
			actor.queue.advance_cursor()
		elif cmd.command_type == AgentCommand.CommandType.SET_FIELD_OF_FIRE:
			actor.field_of_fire_deg = cmd.bearing_deg
			actor.facing_deg = float(cmd.bearing_deg)
			actor.queue.advance_cursor()
		elif cmd.command_type == AgentCommand.CommandType.WAIT_GO_CODE:
			if world.go_codes_issued.has(cmd.go_code) or commander.has_go_code(cmd.go_code):
				actor.queue.advance_cursor()
			else:
				actor.wait_code = cmd.go_code
				return
		elif cmd.command_type == AgentCommand.CommandType.MOVE_TO_CELL:
			if _follow_grid_path(world, actor, cmd.target_cell):
				actor.queue.advance_cursor()
			return
		else:
			actor.queue.advance_cursor()


func _follow_tactical_path(world: SimWorld, actor: SimOperative, goal_cell: Vector2i, danger_weight: int) -> bool:
	var fmap := world.map_on_floor(actor.floor_idx)
	if actor.active_path.is_empty():
		var cells: Array[Vector2i] = influence.find_tactical_path(fmap, GridUtil.cell_of(actor.pos), goal_cell, danger_weight)
		if cells.size() <= 1:
			return true
		var pts := PackedVector2Array()
		for c in cells:
			pts.append(Vector2(c) + Vector2(0.5, 0.5))
		actor.active_path = pts
		actor.path_index = 0
	return _step_active_path(world, actor)


func _follow_grid_path(world: SimWorld, actor: SimOperative, goal_cell: Vector2i) -> bool:
	var fmap := world.map_on_floor(actor.floor_idx)
	if actor.active_path.is_empty():
		var cells: Array[Vector2i] = GridPathfinder.find_path(fmap, GridUtil.cell_of(actor.pos), goal_cell)
		if cells.size() <= 1:
			return true
		var pts := PackedVector2Array()
		for c in cells:
			pts.append(Vector2(c) + Vector2(0.5, 0.5))
		actor.active_path = pts
		actor.path_index = 0
	return _step_active_path(world, actor)


func _step_active_path(world: SimWorld, actor: SimOperative) -> bool:
	var fmap := world.map_on_floor(actor.floor_idx)
	var rem: float = actor.speed_cells_per_sec() * SimWorld.DT
	while rem > 0.00001 and actor.path_index < actor.active_path.size() - 1:
		var tgt: Vector2 = actor.active_path[actor.path_index + 1]
		var delta: Vector2 = tgt - actor.pos
		var dist: float = delta.length()
		if dist <= 0.0001:
			actor.pos = tgt
			actor.path_index += 1
			continue
		var cand: Vector2 = tgt if dist <= rem else actor.pos + delta * (rem / dist)
		var cand_cell: Vector2i = GridUtil.cell_of(cand)
		if not fmap.in_bounds(cand_cell) or fmap.is_solid(cand_cell):
			actor.active_path = PackedVector2Array()
			actor.path_index = 0
			return false
		actor.pos = cand
		if actor.field_of_fire_deg < 0:
			actor.facing_deg = rad_to_deg(delta.angle())
		if dist <= rem:
			rem -= dist
			actor.path_index += 1
		else:
			rem = 0.0
	if actor.path_index >= actor.active_path.size() - 1:
		actor.active_path = PackedVector2Array()
		actor.path_index = 0
		return true
	return false


func _pick_reposition_cell(world: SimWorld, origin: Vector2i, avoid_cell: Vector2i, segs: Array) -> Vector2i:
	var best: Vector2i = influence.best_cover_cell(world.map, origin, Vector2(avoid_cell) + Vector2(0.5, 0.5), 4, {avoid_cell: true}, true, segs)
	if best != InfluenceMap.NO_CELL and best != avoid_cell:
		return best
	for d in InfluenceMap.ORTHO:
		var nb: Vector2i = origin + d
		if world.map.in_bounds(nb) and not world.map.is_solid(nb) and not world.map.door_cells.has(nb) and nb != avoid_cell:
			return nb
	return Vector2i(-1, -1)


func _find_drone(world: SimWorld, drone_id: int) -> SimDrone:
	for d in world.drones:
		if d.id == drone_id:
			return d
	return null


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
		enemy_states[str(id)] = enemy.to_dict()
	return {
		"blackboard": blackboard.to_dict(),
		"enemies": enemy_states,
		"influence": influence.to_dict(),
		"tactics": tactics.to_dict(),
		"commander": commander.to_dict(),
		"last_acoustic_idx": last_acoustic_idx,
	}


static func from_dict(d: Dictionary) -> AiCoordinator:
	var coordinator := AiCoordinator.new()
	coordinator.blackboard = ThreatBlackboard.from_dict(d.get("blackboard", {}))
	var enemy_states: Dictionary = d.get("enemies", {})
	for id in enemy_states:
		var state: Dictionary = enemy_states[id]
		coordinator.enemies[int(id)] = EnemyAi.from_dict(state)
	if d.has("influence"):
		coordinator.influence = InfluenceMap.from_dict(d["influence"])
	if d.has("tactics"):
		coordinator.tactics = SquadTactics.from_dict(d["tactics"])
	if d.has("commander"):
		coordinator.commander = CpuCommander.from_dict(d["commander"])
	coordinator.last_acoustic_idx = int(d.get("last_acoustic_idx", coordinator.blackboard.acoustic.size()))
	return coordinator
