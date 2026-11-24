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
	failures += _test_delta_go_code()
	failures += _test_team_modes()
	failures += _test_override_replay()
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
	for i in range(10):
		w.step()
	w.setup(GreyboxMap.build_default(), 5)
	w.add_operative(0, Vector2i(2, 2), _plan_op0())
	w.add_operative(1, Vector2i(13, 2), _plan_op1())
	var ref := _build_world(5)
	var ok := w.operatives.size() == 2 and w.state_hash() == ref.state_hash()
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
	var h1 := w.state_hash()
	var snap := w.snapshot_data()
	var w2 := SimWorld.new()
	w2.restore_from_data(snap)
	for i in range(2):
		w2.step()
	var ok := w2.override_stream.size() == 1 and w2.state_hash() == h1
	print("[HARNESS] override_replay %s (stream=%d)" % ["PASS" if ok else "FAIL", w2.override_stream.size()])
	return 0 if ok else 1


func _test_visibility_sweepline_ioi() -> int:
	var map := GreyboxMap.build_default()
	var segs := map.get_wall_segments()
	var observer := Vector2(2.5 * 16.0, 2.5 * 16.0)
	var poly := Visibility.compute_polygon(observer, segs, 0.00001)
	var ok := poly.size() >= 3
	var n_rays := 1440
	var match := 0
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
			match += 1
	var ioi := float(match) / float(max(total, 1))
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
