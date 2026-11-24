# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
extends SceneTree

const TICK_BUDGET := 7200


func _initialize() -> void:
	print("PROBE_H_INIT")
	var failures := 0
	failures += _test_command_serialization()
	failures += _test_queue_roundtrip()
	failures += _test_world_snapshot_roundtrip()
	failures += _test_determinism_same_seed()
	failures += _test_rng_state_coverage()
	failures += _test_setup_resets()
	failures += _test_go_code_same_tick()
	failures += _test_route_pipeline()
	failures += _test_camera_clamp()
	failures += _test_execution_move_adherence()
	failures += _test_collision_halt()
	failures += _test_stance_table()
	failures += _test_tactical_actions()
	failures += _test_fof_override()
	failures += _test_visibility_sweepline_ioi()
	failures += _test_visibility_west_corner_wrap()
	failures += _test_wall_faces_occlude()
	failures += _test_route_plan_adherence()
	failures += _test_route_plan_blocked()
	failures += _test_route_plan_corner_rule()
	failures += _test_move_carry_continuity()
	failures += _test_go_code_stream_replay()
	failures += _test_delta_go_code()
	failures += _test_team_modes()
	failures += _test_override_replay()
	failures += _test_faction_fields()
	failures += _test_tapin_cooldowns()
	failures += _test_tapin_cp_budget()
	failures += _test_door_breach()
	failures += _test_ballistics()
	failures += _test_drones()
	failures += _test_vehicles()
	failures += _test_ai_no_wallhack_lkp()
	failures += _test_ai_acoustic_wall_attenuation()
	failures += _test_ai_threat_weighted_flank()
	failures += _test_ai_flashbang_morale_stun()
	failures += _test_ai_lkp_freeze()
	failures += _test_ai_cone_vision()
	failures += _test_ai_acoustic_events()
	failures += _test_ai_hostage_lof_safety()
	failures += _test_ai_determinism_replay()
	print("[HARNESS] RESULT %s failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _cmd_move(target: Vector2i) -> AgentCommand:
	var c := AgentCommand.new()
	c.command_type = AgentCommand.CommandType.MOVE_TO_CELL
	c.target_cell = target
	return c


func _cmd_stance(stance: StringName) -> AgentCommand:
	var c := AgentCommand.new()
	c.command_type = AgentCommand.CommandType.SET_STANCE
	c.stance_name = stance
	return c


func _cmd_wait(code: StringName) -> AgentCommand:
	var c := AgentCommand.new()
	c.command_type = AgentCommand.CommandType.WAIT_GO_CODE
	c.go_code = code
	return c


func _cmd_action(target: Vector2i, kind: AgentCommand.ActionKind) -> AgentCommand:
	var c := AgentCommand.new()
	c.command_type = AgentCommand.CommandType.PERFORM_ACTION
	c.target_cell = target
	c.action_kind = kind
	return c


func _cmd_fof(bearing: int) -> AgentCommand:
	var c := AgentCommand.new()
	c.command_type = AgentCommand.CommandType.SET_FIELD_OF_FIRE
	c.bearing_deg = bearing
	return c


func _plan_op0() -> Array[AgentCommand]:
	var plan: Array[AgentCommand] = []
	plan.append(_cmd_move(Vector2i(7, 2)))
	plan.append(_cmd_stance(&"cautious"))
	plan.append(_cmd_move(Vector2i(7, 4)))
	return plan


func _plan_op1() -> Array[AgentCommand]:
	var plan: Array[AgentCommand] = []
	plan.append(_cmd_move(Vector2i(13, 6)))
	plan.append(_cmd_action(Vector2i(8, 6), AgentCommand.ActionKind.BREACH_CHARGE))
	plan.append(_cmd_wait(&"alpha"))
	plan.append(_cmd_move(Vector2i(2, 6)))
	return plan


func _build_world(seed_value: int) -> SimWorld:
	var w := SimWorld.new()
	w.setup(GreyboxMap.build_default(), seed_value)
	w.add_operative(0, Vector2i(2, 2), _plan_op0())
	w.add_operative(1, Vector2i(13, 2), _plan_op1())
	return w


func _run_mission(seed_value: int, issue_tick: int) -> SimWorld:
	var w := _build_world(seed_value)
	while w.tick < TICK_BUDGET and not w.all_done():
		w.step()
		if w.tick == issue_tick:
			w.issue_go_code(&"alpha")
	return w


func _first_tick(w: SimWorld, ev: StringName, op: int) -> int:
	for e in w.journal:
		if StringName(e["ev"]) == ev and int(e.get("op", -1)) == op:
			return int(e["t"])
	return -1


func _test_command_serialization() -> int:
	var samples: Array[AgentCommand] = [
		_cmd_move(Vector2i(3, 4)),
		_cmd_stance(&"blitz"),
		_cmd_wait(&"bravo"),
		_cmd_action(Vector2i(5, 5), AgentCommand.ActionKind.TEAR_GAS),
		_cmd_fof(45),
	]
	var ok := true
	for c in samples:
		var round_trip := AgentCommand.from_dict(c.to_dict()).to_dict()
		if str(round_trip) != str(c.to_dict()):
			ok = false
			print("[HARNESS] command_serialization MISMATCH")
	print("[HARNESS] command_serialization %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_queue_roundtrip() -> int:
	var q := CommandQueue.new(7)
	q.enqueue(_cmd_move(Vector2i(1, 1)))
	q.enqueue(_cmd_wait(&"charlie"))
	q.enqueue(_cmd_move(Vector2i(9, 9)))
	q.advance_cursor()
	var restored := CommandQueue.from_dict(q.to_dict())
	var ok := str(restored.to_dict()) == str(q.to_dict())
	if restored.peek_next() == null or restored.peek_next().command_type != AgentCommand.CommandType.WAIT_GO_CODE:
		ok = false
	print("[HARNESS] queue_roundtrip %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_world_snapshot_roundtrip() -> int:
	var w := _build_world(424242)
	for i in range(120):
		w.step()
		if w.tick == 60:
			w.issue_go_code(&"alpha")
	var snap := MissionSnapshot.capture(w)
	var hash_a := w.state_hash()
	for i in range(90):
		w.step()
	var hash_b1 := w.state_hash()
	snap.restore_into(w)
	var restore_ok := w.state_hash() == hash_a and w.tick == snap.captured_tick
	for i in range(90):
		w.step()
	var continuation_ok := w.state_hash() == hash_b1
	var ok := restore_ok and continuation_ok
	print("[HARNESS] world_snapshot_roundtrip %s (restore=%s continuation=%s)" % [
		"PASS" if ok else "FAIL",
		str(restore_ok),
		str(continuation_ok),
	])
	return 0 if ok else 1


func _test_determinism_same_seed() -> int:
	var wa := _run_mission(1337, 300)
	var wb := _run_mission(1337, 300)
	var hashes_equal := wa.state_hash() == wb.state_hash()
	var journals_equal := str(wa.journal) == str(wb.journal)
	var completed := wa.all_done() and bool(wa.map.door_open[Vector2i(8, 6)])
	var ok := hashes_equal and journals_equal and completed
	print("[HARNESS] determinism_same_seed %s (hashes_equal=%s journals_equal=%s completed=%s)" % [
		"PASS" if ok else "FAIL",
		str(hashes_equal),
		str(journals_equal),
		str(completed),
	])
	print("[HARNESS] info hashA=%s tickA=%d" % [
		wa.state_hash().substr(0, 12),
		wa.tick,
	])
	return 0 if ok else 1


func _test_rng_state_coverage() -> int:
	var w := _build_world(2024)
	for i in range(30):
		w.step()
	var snap := MissionSnapshot.capture(w)
	var h0 := w.state_hash()
	var draws_a: Array = []
	for i in range(5):
		draws_a.append(w.rng.randi())
	var hash_changed := w.state_hash() != h0
	snap.restore_into(w)
	var draws_b: Array = []
	for i in range(5):
		draws_b.append(w.rng.randi())
	var replay_draws_equal := draws_a == draws_b
	var ok := hash_changed and replay_draws_equal
	print("[HARNESS] rng_state_coverage %s (hash_changed=%s replay_draws_equal=%s)" % [
		"PASS" if ok else "FAIL",
		str(hash_changed),
		str(replay_draws_equal),
	])
	return 0 if ok else 1


func _test_setup_resets() -> int:
	var w := _build_world(5)
	var oc := OverrideCommand.new()
	oc.tick = 1
	oc.op_id = 0
	oc.aim_deg = 45.0
	w.apply_override(oc)
	for i in range(10):
		w.step()
	var spent := w.tapin_points < SimConstants.TAPIN_COMMAND_POINTS_MAX
	w.setup(GreyboxMap.build_default(), 5)
	w.add_operative(0, Vector2i(2, 2), _plan_op0())
	w.add_operative(1, Vector2i(13, 2), _plan_op1())
	var ref := _build_world(5)
	var ok := w.operatives.size() == 2 and w.state_hash() == ref.state_hash()
	ok = ok and spent and w.tapin_points == SimConstants.TAPIN_COMMAND_POINTS_MAX
	ok = ok and w.override_stream.is_empty() and w.tapin_player_cooldown == 0 and w.entity_seq == 0
	print("[HARNESS] setup_resets %s (ops=%d hash_match=%s)" % [
		"PASS" if ok else "FAIL",
		w.operatives.size(),
		str(w.state_hash() == ref.state_hash()),
	])
	return 0 if ok else 1


func _test_go_code_same_tick() -> int:
	var plan_a: Array[AgentCommand] = [_cmd_wait(&"alpha"), _cmd_move(Vector2i(3, 2))]
	var plan_b: Array[AgentCommand] = [_cmd_stance(&"blitz"), _cmd_fof(90), _cmd_wait(&"alpha"), _cmd_move(Vector2i(13, 3))]
	var pre := SimWorld.new()
	pre.setup(GreyboxMap.build_default(), 11)
	pre.add_operative(0, Vector2i(2, 2), plan_a)
	pre.add_operative(1, Vector2i(13, 2), plan_b)
	pre.issue_go_code(&"alpha")
	for i in range(5):
		pre.step()
	var late := SimWorld.new()
	late.setup(GreyboxMap.build_default(), 11)
	late.add_operative(0, Vector2i(2, 2), plan_a)
	late.add_operative(1, Vector2i(13, 2), plan_b)
	for i in range(20):
		late.step()
		if late.tick == 10:
			late.issue_go_code(&"alpha")
	var pre0 := _first_tick(pre, &"move_start", 0)
	var pre1 := _first_tick(pre, &"move_start", 1)
	var late0 := _first_tick(late, &"move_start", 0)
	var late1 := _first_tick(late, &"move_start", 1)
	var ok := pre0 == 1 and pre1 == 1 and late0 == 11 and late1 == 11
	print("[HARNESS] go_code_same_tick %s (pre0=%d pre1=%d late0=%d late1=%d)" % [
		"PASS" if ok else "FAIL",
		pre0,
		pre1,
		late0,
		late1,
	])
	return 0 if ok else 1


func _test_route_pipeline() -> int:
	var prng := RandomNumberGenerator.new()
	prng.seed = 77
	var raw := PackedVector2Array()
	raw.append(Vector2(40, 40))
	var cur := Vector2(40, 40)
	for i in range(400):
		cur += Vector2(prng.randf_range(-3.0, 9.0), prng.randf_range(-4.0, 4.0))
		raw.append(cur)
	var dec1 := RouteSanitizer.decimate(raw)
	var dec2 := RouteSanitizer.decimate(raw)
	var baked := RouteSanitizer.bake_smooth(dec1)
	var baked2 := RouteSanitizer.bake_smooth(dec2)
	var reduced := dec1.size() < raw.size() and dec1.size() >= 2
	var deterministic := dec1 == dec2 and baked == baked2
	var endpoints_kept := baked[0].distance_to(raw[0]) < 0.01 and baked[baked.size() - 1].distance_to(raw[raw.size() - 1]) < 0.01
	var tail_in := PackedVector2Array([Vector2(0, 0), Vector2(20, 0), Vector2(25, 0)])
	var tail_out := RouteSanitizer.decimate(tail_in)
	var tail_kept := tail_out.size() >= 2 and tail_out[tail_out.size() - 1].distance_to(Vector2(25, 0)) < 0.01
	var corner := RouteSanitizer.bake_smooth(PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100)]))
	var corner_dev: float = 0.0
	for i in range(corner.size()):
		var pt: Vector2 = corner[i]
		var c0: Vector2 = Geometry2D.get_closest_point_to_segment(pt, Vector2(0, 0), Vector2(100, 0))
		var c1: Vector2 = Geometry2D.get_closest_point_to_segment(pt, Vector2(100, 0), Vector2(100, 100))
		var d: float = minf(pt.distance_to(c0), pt.distance_to(c1))
		if d > corner_dev:
			corner_dev = d
	var smoothed := corner_dev > 1.0
	var cells := GridUtil.collapse_consecutive_cells(GridUtil.px_points_to_cell_waypoints(baked))
	var cells_sane := cells.size() >= 2 and cells[0] == GridUtil.px_to_cell(raw[0])
	var ok := reduced and deterministic and endpoints_kept and tail_kept and smoothed and cells_sane
	print("[HARNESS] route_pipeline %s (raw=%d decimated=%d baked=%d waypoints=%d corner_dev=%.2f tail_kept=%s)" % [
		"PASS" if ok else "FAIL",
		raw.size(),
		dec1.size(),
		baked.size(),
		cells.size(),
		corner_dev,
		str(tail_kept),
	])
	return 0 if ok else 1


func _test_execution_move_adherence() -> int:
	var w := _build_world(1337)
	var prev: Dictionary = {}
	for op in w.operatives:
		prev[op.id] = op.pos
	var drift_ok := true
	var clip_ok := true
	for i in range(TICK_BUDGET):
		if w.tick >= TICK_BUDGET or w.all_done():
			break
		if w.tick == 300:
			w.issue_go_code(&"alpha")
		w.step()
		for op in w.operatives:
			if op.done or op.halted:
				continue
			if prev[op.id] == op.pos:
				continue
			var prev_pos: Vector2 = prev[op.id]
			var d := (op.pos - prev_pos).length()
			var max_d := op.speed_cells_per_sec() * SimWorld.DT + 0.001
			if d > max_d:
				drift_ok = false
				print("[HARNESS] execution_move_adherence DRIFT op=%d d=%.4f max=%.4f t=%d" % [op.id, d, max_d, i + 1])
			var c := GridUtil.cell_of(op.pos)
			if w.map.is_solid(c) and not w.map.door_cells.has(c):
				clip_ok = false
				print("[HARNESS] execution_move_adherence CLIP op=%d cell=%s t=%d" % [op.id, str(c), i + 1])
			prev[op.id] = op.pos
	var fp := {}
	for op in w.operatives:
		fp[op.id] = op.pos
	var final_ok := bool(w.all_done() and w.map.door_open[Vector2i(8, 6)])
	var op0_pos := fp[0] as Vector2
	var op1_pos := fp[1] as Vector2
	var pos_ok := op0_pos == Vector2(7, 4) + Vector2(0.5, 0.5) and op1_pos == Vector2(2, 6) + Vector2(0.5, 0.5)
	var ok := drift_ok and clip_ok and final_ok and pos_ok
	print("[HARNESS] execution_move_adherence %s (drift_ok=%s clip_ok=%s final_ok=%s pos_ok=%s)" % [
		"PASS" if ok else "FAIL",
		str(drift_ok), str(clip_ok), str(final_ok), str(pos_ok),
	])
	return 0 if ok else 1


func _test_collision_halt() -> int:
	var w := SimWorld.new()
	w.setup(GreyboxMap.build_default(), 99)
	w.add_operative(0, Vector2i(2, 4), [_cmd_move(Vector2i(6, 4))])
	w.add_operative(1, Vector2i(6, 6), [_cmd_move(Vector2i(6, 4))])
	for i in range(40):
		w.step()
	var halted0 := w.operatives[0].halted
	var halted1 := w.operatives[1].halted
	var ok := halted0 and halted1
	print("[HARNESS] collision_halt %s (op0_halted=%s op1_halted=%s op0_done=%s)" % [
		"PASS" if ok else "FAIL",
		str(halted0), str(halted1), str(w.operatives[0].done),
	])
	return 0 if ok else 1


func _test_fof_override() -> int:
	var w := SimWorld.new()
	w.setup(GreyboxMap.build_default(), 8888)
	w.add_operative(0, Vector2i(2, 2), [
		_cmd_move(Vector2i(5, 2)),
		_cmd_fof(90),
		_cmd_move(Vector2i(7, 2)),
	])
	var done := false
	var override_seen := false
	for i in range(300):
		w.step()
		var o := w.operatives[0]
		if o.active_path.size() > 0 and o.field_of_fire_deg == 90 and o.facing_deg == 90:
			override_seen = true
		if o.done:
			done = true
			break
	var ok := done and override_seen and w.operatives[0].field_of_fire_deg == 90
	print("[HARNESS] fof_override %s (done=%s override_seen=%s)" % [
		"PASS" if ok else "FAIL", str(done), str(override_seen),
	])
	return 0 if ok else 1
	print("[HARNESS] fof_override %s (done=%s override_seen=%s)" % [
		"PASS" if ok else "FAIL", str(done), str(override_seen),
	])
	return 0 if ok else 1
	print("[HARNESS] fof_override %s (done=%s override_seen=%s)" % [
		"PASS" if ok else "FAIL", str(done), str(override_seen),
	])
	return 0 if ok else 1


func _test_tactical_actions() -> int:
	var w := SimWorld.new()
	w.setup(GreyboxMap.build_default(), 7777)
	w.add_operative(0, Vector2i(2, 2), [
		_cmd_move(Vector2i(3, 2)),
		_cmd_action(Vector2i(5, 5), AgentCommand.ActionKind.FRAG),
		_cmd_action(Vector2i(6, 5), AgentCommand.ActionKind.FLASHBANG),
		_cmd_action(Vector2i(7, 5), AgentCommand.ActionKind.TEAR_GAS),
	])
	w.add_operative(1, Vector2i(4, 4), [_cmd_wait(&"bravo")])
	var cooldown_seen := false
	var done := false
	for i in range(500):
		if w.tick == 60:
			w.issue_go_code(&"alpha")
		w.step()
		if not cooldown_seen and w.entities.size() > 0 and w.operatives[0].cooldown_ticks == SimConstants.ACTION_COOLDOWN_TICKS:
			cooldown_seen = true
		if w.operatives[0].done and w.entities.size() == 0:
			done = true
			break
	var spawned_kinds: Array[int] = []
	var effect_count := 0
	for e in w.journal:
		var ev := StringName(e["ev"])
		if ev == &"entity_spawned":
			spawned_kinds.append(int(e["kind"]))
		elif ev == &"entity_effect":
			effect_count += 1
	var frag_spawned := spawned_kinds.count(int(AgentCommand.ActionKind.FRAG)) == 1
	var flashbang_spawned := spawned_kinds.count(int(AgentCommand.ActionKind.FLASHBANG)) == 1
	var gas_spawned := spawned_kinds.count(int(AgentCommand.ActionKind.TEAR_GAS)) == 1
	var hp_ok := w.operatives[1].hp == 100 - SimConstants.FRAG_DAMAGE
	var owner_ok := w.operatives[0].hp == 100
	var ok := done and frag_spawned and flashbang_spawned and gas_spawned and effect_count >= 3 and cooldown_seen and hp_ok and owner_ok
	print("[HARNESS] tactical_actions %s (spawned=%d effects=%d cooldown_seen=%s hp_op0=%d hp_op1=%d)" % [
		"PASS" if ok else "FAIL",
		spawned_kinds.size(), effect_count, str(cooldown_seen), w.operatives[0].hp, w.operatives[1].hp,
	])
	return 0 if ok else 1


func _test_delta_go_code() -> int:
	var w := SimWorld.new()
	w.setup(GreyboxMap.build_default(), 1337)
	w.issue_go_code(&"delta")
	var ok := w.go_codes_issued.has(&"delta")
	print("[HARNESS] delta_go_code %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_team_modes() -> int:
	var w := SimWorld.new()
	w.setup(GreyboxMap.build_default(), 1337)
	var o := SimOperative.new()
	o.id = 7
	o.queue = CommandQueue.new(7)
	var c0 := AgentCommand.new()
	c0.command_type = AgentCommand.CommandType.WAIT_GO_CODE
	c0.go_code = &"alpha"
	var c1 := AgentCommand.new()
	c1.command_type = AgentCommand.CommandType.SET_MODE
	c1.mode_name = &"engage"
	o.queue.reset([c0, c1])
	w.operatives.append(o)
	w.issue_go_code(&"alpha")
	for i in range(3):
		w.step()
	var ok := o.mode_name == &"engage"
	print("[HARNESS] team_modes %s (mode=%s)" % ["PASS" if ok else "FAIL", String(o.mode_name)])
	return 0 if ok else 1


func _test_override_replay() -> int:
	var w := SimWorld.new()
	w.setup(GreyboxMap.build_default(), 1337)
	var o := SimOperative.new()
	o.id = 0
	o.pos = Vector2(2.5, 2.5)
	o.queue = CommandQueue.new(0)
	w.operatives.append(o)
	var oc := OverrideCommand.new()
	oc.tick = 1
	oc.op_id = 0
	oc.aim_deg = 90.0
	w.apply_override(oc)
	for i in range(2):
		w.step()
	var snap := w.snapshot_data()
	var w2 := SimWorld.new()
	w2.restore_from_data(snap)
	var restored_equal := w2.state_hash() == w.state_hash()
	for i in range(2):
		w.step()
		w2.step()
	var ok := restored_equal and w2.override_stream.size() == 1 and w2.state_hash() == w.state_hash()
	ok = ok and w2.tapin_points == w.tapin_points and w2.tapin_player_cooldown == w.tapin_player_cooldown
	print("[HARNESS] override_replay %s (stream=%d)" % ["PASS" if ok else "FAIL", w2.override_stream.size()])
	return 0 if ok else 1


func _test_faction_fields() -> int:
	var o := SimOperative.new()
	var ok := o.faction_id == 0 and o.owner_peer_id == -1
	print("[HARNESS] faction_fields %s (f=%d p=%d)" % ["PASS" if ok else "FAIL", o.faction_id, o.owner_peer_id])
	return 0 if ok else 1


func _test_tapin_cooldowns() -> int:
	var w := SimWorld.new()
	w.setup(GreyboxMap.build_default(), 1337)
	var o := SimOperative.new()
	o.id = 0
	o.pos = Vector2(2.5, 2.5)
	o.queue = CommandQueue.new(0)
	w.operatives.append(o)
	var oc := OverrideCommand.new()
	oc.tick = 1
	oc.op_id = 0
	w.apply_override(oc)
	var ok := w.tapin_player_cooldown == SimConstants.TAPIN_HANDOFF_TICKS
	ok = ok and w.tapin_unit_cooldowns.has(0)
	w.step()
	ok = ok and w.tapin_player_cooldown > 0
	w.release_tapin(0)
	ok = ok and w.tapin_player_cooldown == SimConstants.TAPIN_COOLDOWN_TICKS
	print("[HARNESS] tapin_cooldowns %s (player=%d unit=%d)" % ["PASS" if ok else "FAIL", w.tapin_player_cooldown, SimConstants.TAPIN_UNIT_COOLDOWN_TICKS])
	return 0 if ok else 1


func _test_tapin_cp_budget() -> int:
	var w := SimWorld.new()
	w.setup(GreyboxMap.build_default(), 1337)
	var ok := w.tapin_points == SimConstants.TAPIN_COMMAND_POINTS_MAX
	var oc := OverrideCommand.new()
	oc.tick = 1
	w.apply_override(oc)
	ok = ok and w.tapin_points == SimConstants.TAPIN_COMMAND_POINTS_MAX - 1
	print("[HARNESS] tapin_cp_budget %s (points=%d)" % ["PASS" if ok else "FAIL", w.tapin_points])
	return 0 if ok else 1


func _test_door_breach() -> int:
	var ds := DoorSystem.new()
	ds.add_door(Vector2i(8, 6))
	var ok := ds.breach(Vector2i(8, 6), &"c4")
	ok = ok and ds.state(Vector2i(8, 6)) == DoorSystem.State.BREACHED_DESTROYED
	ok = ok and ds.breach(Vector2i(7, 5), &"none")
	print("[HARNESS] door_breach %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_ballistics() -> int:
	var b := BallisticsSuppression.new()
	var ok := b.damage_for(&"7.62", &"heavy_iii_iv") == 1
	ok = ok and b.damage_for(&"7.62", &"light_iia") == 7
	ok = ok and b.damage_for(&"9mm", &"medium_ii") == 1
	ok = ok and b.damage_for(&"5.56", &"shield") == 3
	ok = ok and b.damage_for(&"unknown", &"light_iia") == 0
	print("[HARNESS] ballistics %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_drones() -> int:
	var w := SimWorld.new()
	w.setup(GreyboxMap.build_default(), 1337)
	var d := w.spawn_drone(0)
	var ok := w.drones.size() == 1 and d.kind == SimDrone.Class.GROUND_RECON
	w.destroy_drone(d.id)
	ok = ok and d.destroyed
	print("[HARNESS] drones %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_vehicles() -> int:
	var w := SimWorld.new()
	w.setup(GreyboxMap.build_default(), 1337)
	var v := SimVehicle.new()
	v.type = SimVehicle.Type.RAID_VAN
	w.vehicles.append(v)
	var ok := w.vehicles.size() == 1 and v.type == SimVehicle.Type.RAID_VAN
	print("[HARNESS] vehicles %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_ai_cone_vision() -> int:
	var b := ThreatBlackboard.new()
	var segs := GreyboxMap.build_default().get_wall_segments()
	var ok := b.cone_visible(Vector2(2.5, 2.5), Vector2(5.5, 2.5), 0.0, true, segs)
	ok = ok and b.cone_visible(Vector2(2.5, 2.5), Vector2(5.5, 2.5), -90.0, false, segs) == false
	ok = ok and b.cone_visible(Vector2(2.5, 2.5), Vector2(5.5, 2.5), 0.0, false, segs)
	ok = ok and not b.cone_visible(Vector2(2.5, 2.5), Vector2(500.0, 2.5), 0.0, true, segs)
	ok = ok and not b.cone_visible(Vector2(6.5, 3.5), Vector2(10.5, 3.5), 0.0, true, segs)
	print("[HARNESS] ai_cone_vision %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_ai_acoustic_events() -> int:
	var b := ThreatBlackboard.new()
	b.record_acoustic(Vector2i(8, 6), &"gunshot_unsuppressed", 42)
	var ok := b.acoustic.size() == 1 and int(b.acoustic[0]["t"]) == 42
	print("[HARNESS] ai_acoustic_events %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_ai_no_wallhack_lkp() -> int:
	var b := ThreatBlackboard.new()
	var ok := not b.has_threat(0)
	b.set_threat(0, 5, Vector2(3.0, 4.0))
	ok = ok and b.has_threat(0)
	b.clear_threat(0)
	ok = ok and not b.has_threat(0)
	print("[HARNESS] ai_no_wallhack_lkp %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_ai_acoustic_wall_attenuation() -> int:
	var b := ThreatBlackboard.new()
	var ok := b.hearing_attenuation(0) == 0.0
	ok = ok and is_equal_approx(b.hearing_attenuation(1), -0.35)
	ok = ok and is_equal_approx(b.hearing_attenuation(3), -1.05)
	print("[HARNESS] ai_acoustic_wall_attenuation %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_ai_threat_weighted_flank() -> int:
	var sc := SquadCoordinator.new()
	sc.assign_role(0, SquadCoordinator.Role.FLANKER)
	var ok := sc.role(0) == SquadCoordinator.Role.FLANKER
	sc.assign_role(1, SquadCoordinator.Role.ANCHOR)
	ok = ok and sc.role(1) == SquadCoordinator.Role.ANCHOR
	sc.set_sight_penalty(Vector2i(8, 6), 40)
	ok = ok and sc.sight_penalty_of(Vector2i(8, 6)) == 40
	print("[HARNESS] ai_threat_weighted_flank %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_ai_flashbang_morale_stun() -> int:
	var e := EnemyAi.new()
	e.transition(EnemyAi.State.SUPPRESS_LKP)
	var ok := not e.surrender_check()
	e.suppress_near_miss(100)
	e.morale = 20
	ok = ok and e.surrender_check()
	e.ai_tick()
	ok = ok and e.state == EnemyAi.State.SURRENDER
	e.transition(EnemyAi.State.STUNNED)
	e.ai_tick()
	ok = ok and e.state == EnemyAi.State.SUPPRESS_LKP
	print("[HARNESS] ai_flashbang_morale_stun %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_ai_lkp_freeze() -> int:
	var b := ThreatBlackboard.new()
	var ok := not b.has_threat(0)
	b.set_threat(0, 7, Vector2(12.0, 3.0))
	ok = ok and b.has_threat(0)
	ok = ok and b.lkp_of(0) == Vector2(12.0, 3.0)
	ok = ok and b.target_of(0) == 7
	b.set_alert(0, int(ThreatBlackboard.Alert.ALERTED))
	b.escalate(0)
	ok = ok and int(b.alerts.get(0, 0)) == int(ThreatBlackboard.Alert.COMBAT)
	b.clear_threat(0)
	ok = ok and not b.has_threat(0)
	print("[HARNESS] ai_lkp_freeze %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_ai_hostage_lof_safety() -> int:
	var f := FriendlyReflexAi.new()
	var ok := not f.lof_clear([Vector2i(8, 6)], Vector2(0.0, 100.0), Vector2(256.0, 100.0))
	ok = ok and f.lof_clear([Vector2i(0, 0)], Vector2(0.0, 100.0), Vector2(256.0, 100.0))
	ok = ok and f.mode == FriendlyReflexAi.RoeMode.ENGAGE
	f.set_roe(FriendlyReflexAi.RoeMode.ADVANCE)
	ok = ok and f.mode == FriendlyReflexAi.RoeMode.ADVANCE
	print("[HARNESS] ai_hostage_lof_safety %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_ai_determinism_replay() -> int:
	var w1 := SimWorld.new()
	w1.setup(GreyboxMap.build_default(), 777)
	var w2 := SimWorld.new()
	w2.setup(GreyboxMap.build_default(), 777)
	var ok := w1.state_hash() == w2.state_hash()
	print("[HARNESS] ai_determinism_replay %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_visibility_sweepline_ioi() -> int:
	var map := GreyboxMap.build_default()
	var segs := map.get_wall_segments()
	var observer := Vector2(2.5, 2.5)
	var poly := Visibility.compute_polygon(observer, segs, 0.00001)
	var ok := poly.size() >= 3
	var n_rays := 1440
	var matched := 0
	var total := 0
	for i in range(n_rays):
		var ang := TAU * i / n_rays
		var dir := Vector2(cos(ang), sin(ang))
		var d_ref := -1.0
		for s in segs:
			var t := Visibility._ray_hit_t(observer, dir, s[0], s[1])
			if t > 0 and (d_ref < 0 or t < d_ref):
				d_ref = t
		if d_ref < 0:
			continue
		total += 1
		var d_poly := -1.0
		for j in range(poly.size()):
			var t := Visibility._ray_hit_t(observer, dir, poly[j], poly[(j + 1) % poly.size()])
			if t > 0 and (d_poly < 0 or t < d_poly):
				d_poly = t
		if d_poly < 0:
			ok = false
		elif absf(d_poly - d_ref) <= 0.5:
			matched += 1
	var ioi := float(matched) / float(max(total, 1))
	ok = ok and ioi >= 0.99
	print("[HARNESS] visibility_sweepline_ioi %s (poly=%d rays=%d ioi=%.4f)" % [
		"PASS" if ok else "FAIL", poly.size(), total, ioi,
	])
	return 0 if ok else 1


func _test_stance_table() -> int:
	var expected := {
		"blitz": {&"speed": 6.4, &"acoustic": 1.5},
		"normal": {&"speed": 4.0, &"acoustic": 1.0},
		"cautious": {&"speed": 2.0, &"acoustic": 0.35},
	}
	var ok := true
	for s in expected.keys():
		var sn := StringName(s)
		var o := SimOperative.new()
		o.stance = sn
		var got_speed := float(o.speed_cells_per_sec())
		var got_acoustic := float(SimConstants.STANCE_ACOUSTIC_RADIUS_MULTIPLIERS[sn])
		var exp: Dictionary = expected[s]
		if absf(got_speed - float(exp[&"speed"])) > 0.01 or absf(got_acoustic - float(exp[&"acoustic"])) > 0.01:
			ok = false
			print("[HARNESS] stance_table MISMATCH stance=%s speed=%.4f acoustic=%.4f" % [s, got_speed, got_acoustic])
	var b_op := SimOperative.new()
	b_op.stance = &"blitz"
	var n_op := SimOperative.new()
	n_op.stance = &"normal"
	var c_op := SimOperative.new()
	c_op.stance = &"cautious"
	print("[HARNESS] stance_table %s (blitz=%.4f normal=%.4f cautious=%.4f)" % [
		"PASS" if ok else "FAIL",
		float(b_op.speed_cells_per_sec()), float(n_op.speed_cells_per_sec()), float(c_op.speed_cells_per_sec()),
	])
	return 0 if ok else 1


func _test_camera_clamp() -> int:
	var cam := MissionCamera.new()
	cam.configure_for_map(Vector2(256, 192), Vector2(1080, 1920))
	cam.pan_by(Vector2(-100000, 0))
	var right_ok := absf(cam.position.x - (304.0 - 540.0 / cam.zoom.x)) < 0.01 and absf(cam.position.y - 96.0) < 0.01
	cam.pan_by(Vector2(100000, 0))
	var left_ok := absf(cam.position.x - (-48.0 + 540.0 / cam.zoom.x)) < 0.01
	cam.free()
	var ok := right_ok and left_ok
	print("[HARNESS] camera_clamp %s (right_ok=%s left_ok=%s)" % [
		"PASS" if ok else "FAIL",
		str(right_ok),
		str(left_ok),
	])
	return 0 if ok else 1


func _test_visibility_west_corner_wrap() -> int:
	var segs := [
		[Vector2(0, 0), Vector2(10, 0)],
		[Vector2(10, 0), Vector2(10, 10)],
		[Vector2(10, 10), Vector2(0, 10)],
		[Vector2(0, 10), Vector2(0, 0)],
		[Vector2(2, 5), Vector2(2, 2)],
	]
	var observer := Vector2(5, 5)
	var poly := Visibility.compute_polygon(observer, segs, SimConstants.LOS_VERTEX_EPSILON_RAD)
	var ok := poly.size() >= 3
	var vertex_hit := false
	var graze_t := -1.0
	for p in poly:
		if p.distance_to(Vector2(2, 5)) < 0.001:
			vertex_hit = true
		if absf(p.x) < 0.001 and absf(p.y - 5.0) < 0.001:
			graze_t = p.distance_to(observer)
		if p.x < -0.001 or p.y < -0.001 or p.x > 10.001 or p.y > 10.001:
			ok = false
	ok = ok and vertex_hit and absf(graze_t - 5.0) < 0.001
	print("[HARNESS] visibility_west_corner_wrap %s (poly=%d t=%.4f)" % ["PASS" if ok else "FAIL", poly.size(), graze_t])
	return 0 if ok else 1


func _test_wall_faces_occlude() -> int:
	var m := GreyboxMap.build_default()
	var segs := m.get_wall_segments()
	var ok := segs.size() >= 8
	for s in segs:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		ok = ok and (a.x == b.x or a.y == b.y)
		ok = ok and a.x >= 0.0 and a.y >= 0.0 and a.x <= 16.0 and a.y <= 12.0 and b.x <= 16.0 and b.y <= 12.0
	var left := Vector2(6.5, 6.5)
	var right := Vector2(10.5, 6.5)
	var closed_poly := Visibility.compute_polygon(left, segs, SimConstants.LOS_VERTEX_EPSILON_RAD)
	ok = ok and not Geometry2D.is_point_in_polygon(right, closed_poly)
	ok = ok and not Geometry2D.is_point_in_polygon(Vector2(10.5, 3.5), closed_poly)
	ok = ok and Geometry2D.is_point_in_polygon(Vector2(4.5, 6.5), closed_poly)
	m.open_door(Vector2i(8, 6))
	var open_poly := Visibility.compute_polygon(left, m.get_wall_segments(), SimConstants.LOS_VERTEX_EPSILON_RAD)
	ok = ok and Geometry2D.is_point_in_polygon(right, open_poly)
	ok = ok and not Geometry2D.is_point_in_polygon(Vector2(10.5, 3.5), open_poly)
	print("[HARNESS] wall_faces_occlude %s (segs=%d closed=%d open=%d)" % ["PASS" if ok else "FAIL", segs.size(), closed_poly.size(), open_poly.size()])
	return 0 if ok else 1


func _run_until_done(w: SimWorld, budget: int) -> Array[Vector2i]:
	var visited: Array[Vector2i] = [GridUtil.cell_of(w.operatives[0].pos)]
	for i in range(budget):
		w.step()
		var c := GridUtil.cell_of(w.operatives[0].pos)
		if c != visited[visited.size() - 1]:
			visited.append(c)
		var all_done := true
		for o in w.operatives:
			if not o.done and not o.halted:
				all_done = false
		if all_done:
			break
	return visited


func _test_route_plan_adherence() -> int:
	var m := GreyboxMap.build_default()
	var start := Vector2i(2, 2)
	var waypoints: Array[Vector2i] = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 3), Vector2i(5, 4), Vector2i(5, 5), Vector2i(6, 7), Vector2i(4, 9)]
	var res := RoutePlanner.plan(m, start, waypoints)
	var cells: Array[Vector2i] = res["cells"]
	var commands: Array[AgentCommand] = res["commands"]
	var w := SimWorld.new()
	w.setup(m, 21)
	w.add_operative(0, start, commands)
	var visited := _run_until_done(w, TICK_BUDGET)
	var expected: Array[Vector2i] = [start]
	for c in cells:
		expected.append(c)
	var ok: bool = res["blocked_at"] == RoutePlanner.NO_CELL and commands.size() == cells.size()
	ok = ok and visited == expected and w.operatives[0].done and not w.operatives[0].halted
	for i in range(1, expected.size()):
		var d := expected[i] - expected[i - 1]
		ok = ok and absi(d.x) + absi(d.y) == 1
	print("[HARNESS] route_plan_adherence %s (cells=%d visited=%d tick=%d)" % ["PASS" if ok else "FAIL", cells.size(), visited.size(), w.tick])
	return 0 if ok else 1


func _test_route_plan_blocked() -> int:
	var m := GreyboxMap.build_default()
	var waypoints: Array[Vector2i] = [Vector2i(6, 3), Vector2i(7, 3), Vector2i(8, 3), Vector2i(9, 3), Vector2i(10, 3)]
	var res := RoutePlanner.plan(m, Vector2i(5, 3), waypoints)
	var cells: Array[Vector2i] = res["cells"]
	var ok: bool = res["blocked_at"] == Vector2i(8, 3)
	ok = ok and cells == [Vector2i(6, 3), Vector2i(7, 3)]
	var through_door: Array[Vector2i] = [Vector2i(7, 6), Vector2i(8, 6), Vector2i(9, 6)]
	var door_res := RoutePlanner.plan(m, Vector2i(6, 6), through_door)
	var door_cells: Array[Vector2i] = door_res["cells"]
	ok = ok and door_res["blocked_at"] == RoutePlanner.NO_CELL and door_cells.size() == 3
	print("[HARNESS] route_plan_blocked %s (kept=%d)" % ["PASS" if ok else "FAIL", cells.size()])
	return 0 if ok else 1


func _test_route_plan_corner_rule() -> int:
	var m := GreyboxMap.build_default()
	m.solid_cells[Vector2i(3, 4)] = true
	var diag: Array[Vector2i] = [Vector2i(3, 5)]
	var res := RoutePlanner.plan(m, Vector2i(2, 4), diag)
	var cells: Array[Vector2i] = res["cells"]
	var ok := cells == [Vector2i(2, 5), Vector2i(3, 5)]
	var diag_open: Array[Vector2i] = [Vector2i(5, 3)]
	var open_res := RoutePlanner.plan(m, Vector2i(4, 2), diag_open)
	var open_cells: Array[Vector2i] = open_res["cells"]
	ok = ok and open_cells == [Vector2i(5, 2), Vector2i(5, 3)]
	m.solid_cells[Vector2i(2, 5)] = true
	var boxed := RoutePlanner.plan(m, Vector2i(2, 4), diag)
	var boxed_cells: Array[Vector2i] = boxed["cells"]
	ok = ok and boxed["blocked_at"] == Vector2i(3, 5) and boxed_cells.is_empty()
	print("[HARNESS] route_plan_corner_rule %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_move_carry_continuity() -> int:
	var m := GreyboxMap.build_default()
	var single := SimWorld.new()
	single.setup(m, 3)
	var one: Array[AgentCommand] = [_cmd_stance(&"blitz"), _cmd_move(Vector2i(7, 2))]
	single.add_operative(0, Vector2i(2, 2), one)
	_run_until_done(single, TICK_BUDGET)
	var stepped := SimWorld.new()
	stepped.setup(GreyboxMap.build_default(), 3)
	var many: Array[AgentCommand] = [_cmd_stance(&"blitz")]
	for x in range(3, 8):
		many.append(_cmd_move(Vector2i(x, 2)))
	stepped.add_operative(0, Vector2i(2, 2), many)
	_run_until_done(stepped, TICK_BUDGET)
	var ok := single.operatives[0].done and stepped.operatives[0].done
	ok = ok and absi(single.tick - stepped.tick) <= 1
	ok = ok and single.operatives[0].pos.distance_to(stepped.operatives[0].pos) < 0.0001
	print("[HARNESS] move_carry_continuity %s (single=%d stepped=%d)" % ["PASS" if ok else "FAIL", single.tick, stepped.tick])
	return 0 if ok else 1


func _test_go_code_stream_replay() -> int:
	var plan: Array[AgentCommand] = [_cmd_wait(&"alpha"), _cmd_move(Vector2i(5, 2))]
	var a := SimWorld.new()
	a.setup(GreyboxMap.build_default(), 9)
	a.add_operative(0, Vector2i(2, 2), plan)
	for i in range(20):
		a.step()
	var waiting := not a.operatives[0].done and a.operatives[0].pos.distance_to(Vector2(2.5, 2.5)) < 0.0001
	var hash_before := a.state_hash()
	a.schedule_go_code(&"alpha")
	var pending_hash_differs := a.state_hash() != hash_before
	var snap := a.snapshot_data()
	for i in range(200):
		a.step()
	var b := SimWorld.new()
	b.setup(GreyboxMap.build_default(), 9)
	b.add_operative(0, Vector2i(2, 2), plan)
	b.go_code_stream = a.go_code_stream.duplicate(true)
	for i in range(220):
		b.step()
	var c := SimWorld.new()
	c.restore_from_data(snap)
	for i in range(200):
		c.step()
	var ok := waiting and a.operatives[0].done and a.go_codes_issued.has(&"alpha")
	ok = ok and a.state_hash() == b.state_hash() and a.state_hash() == c.state_hash()
	var released := -1
	for e in a.journal:
		if StringName(e["ev"]) == &"go_issued":
			released = int(e["t"])
	ok = ok and released == 21 and pending_hash_differs
	print("[HARNESS] go_code_stream_replay %s (issued_tick=%d)" % ["PASS" if ok else "FAIL", released])
	return 0 if ok else 1
