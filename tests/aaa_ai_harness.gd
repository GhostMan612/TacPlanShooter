# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
extends SceneTree

var _initialized := false


func _init() -> void:
	call_deferred("_ensure_initialized")


func _ensure_initialized() -> void:
	if not _initialized:
		_initialize()


func _initialize() -> void:
	if _initialized:
		return
	_initialized = true
	var failures := 0
	failures += _test_goap_flush_cover()
	failures += _test_bounding_overwatch()
	failures += _test_tactical_reload_cover()
	failures += _test_anti_drone_reposition()
	failures += _test_cpu_commander_preplan()
	failures += _test_aaa_ai_determinism()
	print("[AAA_AI] RESULT %s failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _walled_box(w: int, h: int) -> GreyboxMap:
	var m := GreyboxMap.new()
	m.width_cells = w
	m.height_cells = h
	for x in range(w):
		m.solid_cells[Vector2i(x, 0)] = true
		m.solid_cells[Vector2i(x, h - 1)] = true
	for y in range(h):
		m.solid_cells[Vector2i(0, y)] = true
		m.solid_cells[Vector2i(w - 1, y)] = true
	return m


func _has_callout(world: SimWorld, text: String) -> bool:
	for e in world.journal:
		if StringName(String(e.get("ev", ""))) == &"ai_callout" and String(e.get("callout", "")) == text:
			return true
	return false


func _test_goap_flush_cover() -> int:
	var m := _walled_box(12, 8)
	m.solid_cells[Vector2i(6, 3)] = true
	var w := SimWorld.new()
	w.setup(m, 101)
	var none: Array[AgentCommand] = []
	var op := w.add_operative(0, Vector2i(7, 3), none)
	op.facing_deg = 180.0
	var flanker := w.add_enemy(10, Vector2i(4, 3), &"tactical_flanker", 0.0)
	w.ai.blackboard.set_threat(10, 0, op.pos)
	var static_mask: int = GoapActions.facts_to_mask({
		"lkp_known": true,
		"target_in_cover": true,
		"has_flashbang": true,
	})
	var static_plan: Dictionary = GoapPlanner.plan_for_unit(static_mask, int(SquadCoordinator.Role.ANCHOR), 4, true, true)
	var static_steps: Array[StringName] = static_plan["actions"]
	var plan_ok: bool = static_steps == [&"MoveToThrowAngle", &"ThrowFragOrFlash", &"AdvanceOnStunned"]
	var saw_throw := false
	var saw_advanced := false
	for i in range(180):
		w.step()
		if not w.entities.is_empty():
			saw_throw = true
		if GridUtil.cell_of(flanker.pos).x >= 5 and CombatSystem.line_clear(flanker.pos, op.pos, m.get_wall_segments()):
			saw_advanced = true
	var suppressed_ok: bool = w.ballistics.suppressed_ticks(0) > 0 or _has_callout(w, "FLASH_OUT")
	var ok: bool = plan_ok and saw_throw and _has_callout(w, "FLASH_OUT") and suppressed_ok and saw_advanced
	print("[AAA_AI] goap_flush_cover %s (plan=%s throw=%s adv=%s)" % ["PASS" if ok else "FAIL", str(static_steps), str(saw_throw), str(saw_advanced)])
	return 0 if ok else 1


func _test_bounding_overwatch() -> int:
	var m := GreyboxMap.build_default()
	m.solid_cells.erase(Vector2i(8, 2))
	m.door_cells[Vector2i(8, 2)] = true
	m.door_open[Vector2i(8, 2)] = true
	m.open_door(Vector2i(8, 6))
	var w := SimWorld.new()
	w.setup(m, 202)
	var none: Array[AgentCommand] = []
	var op := w.add_operative(0, Vector2i(4, 6), none)
	op.facing_deg = 0.0
	var sup := w.add_enemy(10, Vector2i(10, 6), &"heavy_gunner", 180.0)
	var flank := w.add_enemy(11, Vector2i(10, 5), &"tactical_flanker", 180.0)
	w.ai.blackboard.set_threat(10, 0, op.pos)
	w.ai.blackboard.set_threat(11, 0, op.pos)
	w.ai.blackboard.set_alert(10, int(ThreatBlackboard.Alert.COMBAT))
	w.ai.blackboard.set_alert(11, int(ThreatBlackboard.Alert.COMBAT))
	var entered_funnel := false
	var crossed_north_safe := false
	var danger_at_funnel: int = 0
	var init_roles_ok := false
	for i in range(260):
		w.step()
		if w.tick == 1:
			init_roles_ok = w.ai.squad.role(sup.id) == int(SquadCoordinator.Role.SUPPRESSOR) and w.ai.squad.role(flank.id) == int(SquadCoordinator.Role.FLANKER)
		danger_at_funnel = maxi(danger_at_funnel, w.ai.influence.effective_danger(Vector2i(8, 6)))
		var fc := GridUtil.cell_of(flank.pos)
		if fc == Vector2i(8, 6):
			entered_funnel = true
		if fc.x <= 8 and fc.y <= 3:
			crossed_north_safe = true
	var roles_ok: bool = init_roles_ok and w.ai.tactics.bound_epoch >= 1
	var callouts_ok: bool = _has_callout(w, "SUPPRESSING") and (_has_callout(w, "FLANKING_LEFT") or _has_callout(w, "FLANKING_RIGHT"))
	var ok: bool = danger_at_funnel > 0 and roles_ok and callouts_ok and not entered_funnel and crossed_north_safe
	print("[AAA_AI] bounding_overwatch %s (danger86=%d roles=%s safe_north=%s funnel=%s)" % ["PASS" if ok else "FAIL", danger_at_funnel, str(roles_ok), str(crossed_north_safe), str(entered_funnel)])
	return 0 if ok else 1


func _test_tactical_reload_cover() -> int:
	var m := _walled_box(12, 8)
	m.solid_cells[Vector2i(5, 3)] = true
	m.solid_cells[Vector2i(5, 4)] = true
	var segs: Array = m.get_wall_segments()
	var w := SimWorld.new()
	w.setup(m, 303)
	var none: Array[AgentCommand] = []
	var op := w.add_operative(0, Vector2i(9, 4), none)
	op.facing_deg = 180.0
	var unit := w.add_enemy(10, Vector2i(6, 5), &"room_anchor", 0.0)
	var brain: EnemyAi = w.ai.enemies[10]
	brain.ammo = 2
	w.ai.blackboard.set_threat(10, 0, op.pos)
	var reloaded_in_cover := false
	var saw_refill := false
	for i in range(200):
		w.step()
		if brain.reload_ticks_left > 0:
			var uc := GridUtil.cell_of(unit.pos)
			if w.ai.influence.is_hard_cover_from(w.map, uc, op.pos, segs):
				reloaded_in_cover = true
		if brain.ammo == brain.mag_size:
			saw_refill = true
	var ok: bool = _has_callout(w, "RELOADING_COVER_ME") and reloaded_in_cover and saw_refill
	print("[AAA_AI] tactical_reload_cover %s (in_cover=%s refilled=%s ammo=%d)" % ["PASS" if ok else "FAIL", str(reloaded_in_cover), str(saw_refill), brain.ammo])
	return 0 if ok else 1


func _test_anti_drone_reposition() -> int:
	var w1 := SimWorld.new()
	w1.setup(GreyboxMap.build_default(), 404)
	var e1 := w1.add_enemy(10, Vector2i(3, 3), &"tech_jammer", 0.0)
	w1.cpu_commander.active_jammers.append(Vector2i(3, 3))
	var d1 := w1.spawn_drone(0)
	d1.pos = Vector2(5.5, 3.5)
	for i in range(80):
		w1.step()
	var jammed_ok: bool = d1.destroyed and _has_callout(w1, "DRONE_SPOTTED") and GridUtil.cell_of(e1.pos) != Vector2i(3, 3)

	var w2 := SimWorld.new()
	w2.setup(GreyboxMap.build_default(), 405)
	var e2 := w2.add_enemy(10, Vector2i(3, 3), &"patrol_sentry", 0.0)
	(w2.ai.enemies[10] as EnemyAi).ammo = 0
	var d2 := w2.spawn_drone(0)
	d2.pos = Vector2(5.5, 3.5)
	for i in range(80):
		w2.step()
	var evade_ok: bool = _has_callout(w2, "DRONE_SPOTTED") and GridUtil.cell_of(e2.pos) != Vector2i(3, 3)
	var ok: bool = jammed_ok and evade_ok
	print("[AAA_AI] anti_drone_reposition %s (jammed=%s evade=%s)" % ["PASS" if ok else "FAIL", str(jammed_ok), str(evade_ok)])
	return 0 if ok else 1


func _test_cpu_commander_preplan() -> int:
	var m := MapLoader.load_from_json("res://data/maps/op01_glass_house.json")
	var w := SimWorld.new()
	w.setup(m, 505)
	var res: Dictionary = w.cpu_commander.generate_preplan(w, &"DEFEND", SquadTactics.Doctrine.VETERAN, 3)
	var topo: Dictionary = res["topology"]
	var funnels: Array = topo["fatal_funnels"]
	var cf: Array = res["crossfire"]
	var focal: Vector2i = res["focal_cell"]
	var queues_ok := w.enemy_actors.size() >= 3
	for id in w.enemy_actors.keys():
		var actor: SimOperative = w.enemy_actors[id]
		if actor.queue == null or actor.queue.commands.is_empty():
			queues_ok = false
	var crossfire_ok: bool = cf.size() >= 2
	if crossfire_ok:
		var c0: Vector2i = cf[0]["cell"]
		var c1: Vector2i = cf[1]["cell"]
		crossfire_ok = c0 != c1 and not SquadTactics.blocks_lof(c0, focal, c1) and not SquadTactics.blocks_lof(c1, focal, c0)
	var topo_ok: bool = funnels.has(Vector2i(5, 2)) and not (topo["cover_corners"] as Array).is_empty() and not (topo["objective_sightlines"] as Array).is_empty()
	w.ai.blackboard.alert_level = int(ThreatBlackboard.Alert.COMBAT)
	w.step()
	var live_go: bool = w.cpu_commander.has_go_code(&"alpha")
	var ok: bool = topo_ok and queues_ok and crossfire_ok and w.cpu_commander.active_jammers.size() >= 1 and live_go
	print("[AAA_AI] cpu_commander_preplan %s (units=%d crossfire=%d go_alpha=%s)" % ["PASS" if ok else "FAIL", w.enemy_actors.size(), cf.size(), str(live_go)])
	return 0 if ok else 1


func _build_skirmish(seed_val: int) -> SimWorld:
	var m := MapLoader.load_from_json("res://data/maps/op01_glass_house.json")
	var w := SimWorld.new()
	w.setup(m, seed_val)
	w.cpu_commander.generate_preplan(w, &"DEFEND", SquadTactics.Doctrine.VETERAN, 3)
	var p0: Array[AgentCommand] = [_cmd_move(Vector2i(4, 2)), _cmd_move(Vector2i(6, 5))]
	var p1: Array[AgentCommand] = [_cmd_move(Vector2i(3, 6)), _cmd_move(Vector2i(7, 8))]
	w.add_operative(0, Vector2i(2, 2), p0)
	w.add_operative(1, Vector2i(2, 3), p1)
	var d := w.spawn_drone(0)
	d.pos = Vector2(6.5, 4.5)
	return w


func _test_aaa_ai_determinism() -> int:
	var a := _build_skirmish(2026)
	var b := _build_skirmish(2026)
	var snap: MissionSnapshot = null
	for i in range(240):
		a.step()
		b.step()
		if a.tick == 90:
			snap = MissionSnapshot.capture(a)
	var c := SimWorld.new()
	c.restore_from_data(snap.data)
	var snap_match: bool = c.tick == 90
	for i in range(150):
		c.step()
	var hash_ab: bool = a.state_hash() == b.state_hash()
	var hash_ac: bool = a.state_hash() == c.state_hash()
	var journal_ab: bool = JSON.stringify(a.journal) == JSON.stringify(b.journal)
	var ok: bool = snap_match and hash_ab and hash_ac and journal_ab
	print("[AAA_AI] aaa_ai_determinism %s (ab=%s ac=%s journal=%s)" % ["PASS" if ok else "FAIL", str(hash_ab), str(hash_ac), str(journal_ab)])
	return 0 if ok else 1


func _cmd_move(target: Vector2i) -> AgentCommand:
	var c := AgentCommand.new()
	c.command_type = AgentCommand.CommandType.MOVE_TO_CELL
	c.target_cell = target
	return c
