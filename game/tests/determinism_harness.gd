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
	var wc := _run_mission(9001, 300)
	var hashes_equal := wa.state_hash() == wb.state_hash()
	var journals_equal := str(wa.journal) == str(wb.journal)
	var cross_seed_differs := wa.state_hash() != wc.state_hash()
	var ok := hashes_equal and journals_equal
	print("[HARNESS] determinism_same_seed %s (hashes_equal=%s journals_equal=%s cross_seed_differs=%s)" % [
		"PASS" if ok else "FAIL",
		str(hashes_equal),
		str(journals_equal),
		str(cross_seed_differs),
	])
	print("[HARNESS] info hashA=%s hashC=%s doneA=%s tickA=%d door86_open=%s fuse_journal_present=%s" % [
		wa.state_hash().substr(0, 12),
		wc.state_hash().substr(0, 12),
		str(wa.all_done()),
		wa.tick,
		str(bool(wa.map.door_open[Vector2i(8, 6)])),
		str(str(wa.journal).contains("fuse")),
	])
	return 0 if ok else 1
