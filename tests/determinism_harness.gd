# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name DeterminismHarness
extends SceneTree

const TICK_BUDGET := 7200


func _initialize() -> void:
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
	plan.append(_cmd_move(Vector2i(7, 9)))
	plan.append(_cmd_wait(&"alpha"))
	plan.append(_cmd_move(Vector2i(13, 9)))
	plan.append(_cmd_fof(270))
	plan.append(_cmd_move(Vector2i(13, 2)))
	return plan


func _plan_op1() -> Array[AgentCommand]:
	var plan: Array[AgentCommand] = []
	plan.append(_cmd_move(Vector2i(13, 6)))
	plan.append(_cmd_action(Vector2i(8, 6), AgentCommand.ActionKind.BREACH_CHARGE))
	plan.append(_cmd_wait(&"alpha"))
	plan.append(_cmd_move(Vector2i(9, 6)))
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
