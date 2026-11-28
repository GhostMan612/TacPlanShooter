# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
extends SceneTree


const SAMPLE_TICKS: Array[int] = [0, 5, 10, 15, 20]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[REPLAY] BEGIN")
	var failures := 0
	failures += _test_roundtrip()
	failures += _test_override_accounting()
	failures += _test_scrub_parity()
	failures += _test_multi_floor()
	failures += _test_negative()
	print("[REPLAY] RESULT %s failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
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


func _plan_a() -> Array[AgentCommand]:
	var plan: Array[AgentCommand] = []
	plan.append(_cmd_move(Vector2i(7, 2)))
	plan.append(_cmd_stance(&"cautious"))
	plan.append(_cmd_move(Vector2i(7, 4)))
	return plan


func _plan_b() -> Array[AgentCommand]:
	var plan: Array[AgentCommand] = []
	plan.append(_cmd_move(Vector2i(13, 6)))
	plan.append(_cmd_wait(&"alpha"))
	plan.append(_cmd_move(Vector2i(2, 6)))
	return plan


func _record_fixture(seed_value: int, issue_tick: int, override_tick: int, total_ticks: int) -> Dictionary:
	var w := SimWorld.new()
	w.setup(GreyboxMap.build_default(), seed_value)
	w.add_operative(0, Vector2i(2, 2), _plan_a())
	w.add_operative(1, Vector2i(13, 2), _plan_b())
	var initial := MissionSnapshot.capture(w)
	var go_codes: Array[Dictionary] = []
	var overrides: Array[OverrideCommand] = []
	var samples: Dictionary = {}
	samples[0] = w.state_hash()
	while w.tick < total_ticks:
		if w.tick == issue_tick - 1:
			w.schedule_go_code(&"alpha")
			go_codes.append({"t": w.tick + 1, "code": "alpha"})
		if w.tick == override_tick - 1:
			var oc := OverrideCommand.new()
			oc.tick = override_tick
			oc.op_id = 0
			oc.move_dir = Vector2(1, 0)
			oc.aim_deg = 90.0
			oc.fire_pressed = true
			w.apply_override(oc)
			overrides.append(oc)
		w.step()
		if SAMPLE_TICKS.has(w.tick):
			samples[w.tick] = w.state_hash()
	var manifest := ReplayManifest.create(w, initial, go_codes, overrides, "op01")
	return {
		"manifest": manifest,
		"snapshot": initial.data.duplicate(true),
		"events": ReplayPlayer.manifest_events(manifest),
		"samples": samples,
	}


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _fixture_ok(f: Dictionary, failures: Array[String]) -> bool:
	var ok := f.has("manifest") and f["manifest"] is ReplayManifest and f.has("events")
	_expect(ok, "fixture", failures)
	return ok


func _test_roundtrip() -> int:
	var failures: Array[String] = []
	var f := _record_fixture(1337, 5, 9, 40)
	if not _fixture_ok(f, failures):
		return failures.size()
	var manifest: ReplayManifest = f["manifest"]
	var d := manifest.to_dict()
	var rebuilt := ReplayManifest.from_dict(d)
	_expect(rebuilt.integrity_ok(), "integrity_ok_dict", failures)
	_expect(rebuilt.final_state_hash == manifest.final_state_hash, "final_hash_roundtrip", failures)
	_expect(rebuilt.input_stream.size() == manifest.input_stream.size(), "event_count_roundtrip", failures)
	var text := JSON.stringify(d, "", true, true)
	var parsed: Variant = JSON.parse_string(text)
	_expect(parsed is Dictionary, "json_parse", failures)
	if parsed is Dictionary:
		var from_json := ReplayManifest.from_dict(parsed as Dictionary)
		_expect(from_json.integrity_ok(), "integrity_ok_json", failures)
		var verdict := ReplayPlayer.verify(from_json)
		_expect(bool(verdict["ok"]), "verify_json:%s" % String(verdict.get("reason", "")), failures)
		_expect(int(verdict["ticks"]) == manifest.terminal_tick, "verify_ticks", failures)
	for issue in failures:
		print("[REPLAY] FAIL roundtrip %s" % issue)
	return failures.size()


func _test_override_accounting() -> int:
	var failures: Array[String] = []
	var f := _record_fixture(1337, 5, 9, 40)
	if not _fixture_ok(f, failures):
		return failures.size()
	var manifest: ReplayManifest = f["manifest"]
	var verdict := ReplayPlayer.verify(manifest)
	_expect(bool(verdict["ok"]), "verify_protocol:%s" % String(verdict.get("reason", "")), failures)
	_expect(String(verdict.get("journal_actual", "")) == String(verdict.get("journal_expected", "")), "journal_digest", failures)
	var has_override := false
	for e in manifest.input_stream:
		if String(e.get("kind", "")) == ReplayManifest.OVERRIDE_KIND:
			has_override = true
	_expect(has_override, "override_recorded", failures)
	var bad := SimWorld.new()
	bad.restore_from_data(f["snapshot"])
	for e in manifest.input_stream:
		if String(e.get("kind", "")) == ReplayManifest.GO_CODE_KIND:
			bad.go_code_stream.append({"t": int(e.get("tick", 0)), "code": String(e.get("code", ""))})
		else:
			bad.override_stream.append(OverrideCommand.from_dict(e.get("data", {})))
	while bad.tick < manifest.terminal_tick:
		bad.step()
	_expect(bad.state_hash() != manifest.final_state_hash, "direct_injection_must_diverge", failures)
	for issue in failures:
		print("[REPLAY] FAIL override %s" % issue)
	return failures.size()


func _test_scrub_parity() -> int:
	var failures: Array[String] = []
	var f := _record_fixture(2026, 4, 8, 30)
	if not _fixture_ok(f, failures):
		return failures.size()
	var snapshot: Dictionary = f["snapshot"]
	var events: Array = f["events"]
	var samples: Dictionary = f["samples"]
	for t in SAMPLE_TICKS:
		var w := SimWorld.new()
		_expect(ReplayPlayer.replay_into(w, snapshot, events, t), "replay_ok_%d" % t, failures)
		_expect(int(w.tick) == t, "tick_%d" % t, failures)
		_expect(w.state_hash() == String(samples[t]), "hash_%d" % t, failures)
	for issue in failures:
		print("[REPLAY] FAIL scrub %s" % issue)
	return failures.size()


func _test_multi_floor() -> int:
	var failures: Array[String] = []
	var map := GreyboxMap.load_from_json("res://data/maps/op05_penthouse_lock.json")
	_expect(map != null, "map_load", failures)
	if map == null:
		return failures.size()
	var w := SimWorld.new()
	w.setup(map, 1337)
	var plan: Array[AgentCommand] = [_cmd_move(Vector2i(7, 6))]
	w.add_operative(0, Vector2i(6, 6), plan)
	var initial := MissionSnapshot.capture(w)
	for i in range(30):
		w.step()
	var manifest := ReplayManifest.create(w, initial, [], [], "op05")
	var verdict := ReplayPlayer.verify(manifest)
	_expect(bool(verdict["ok"]), "verify_multifloor:%s" % String(verdict.get("reason", "")), failures)
	_expect(manifest.initial_snapshot.get("floor_maps", []).size() > 0, "floor_slices", failures)
	for issue in failures:
		print("[REPLAY] FAIL multifloor %s" % issue)
	return failures.size()


func _has(reasons: Array[String], token: String) -> bool:
	for r in reasons:
		if r.begins_with(token):
			return true
	return false


func _test_negative() -> int:
	var failures: Array[String] = []
	var base := _record_fixture(1337, 5, 9, 40)
	if not _fixture_ok(base, failures):
		return failures.size()
	var manifest: ReplayManifest = base["manifest"]
	var d := manifest.to_dict()
	d["final_state_hash"] = "0".repeat(64)
	var tampered := ReplayManifest.from_dict(d)
	var verdict := ReplayPlayer.verify(tampered)
	_expect(not bool(verdict["ok"]), "tampered_final_hash", failures)
	d = manifest.to_dict()
	d["integrity_hash"] = "0".repeat(64)
	_expect(not ReplayManifest.from_dict(d).integrity_ok(), "bad_integrity", failures)
	_expect(ReplayManifest.MAX_BYTES == 4194304, "size_cap", failures)
	d = manifest.to_dict()
	d["schema_version"] = 2
	_expect(_has(ReplayManifest.validate(d), "schema_version"), "future_schema", failures)
	d = manifest.to_dict()
	var events: Array = d["input_stream"]
	events[0]["kind"] = "unknown"
	d["input_stream"] = events
	_expect(_has(ReplayManifest.validate(d), "event_kind"), "unknown_kind", failures)
	d = manifest.to_dict()
	events = d["input_stream"]
	events[0]["seq"] = events[1]["seq"]
	d["input_stream"] = events
	_expect(_has(ReplayManifest.validate(d), "duplicate_seq"), "duplicate_seq", failures)
	d = manifest.to_dict()
	events = d["input_stream"]
	events[0]["tick"] = 0
	d["input_stream"] = events
	_expect(_has(ReplayManifest.validate(d), "event_tick"), "bad_tick", failures)
	d = manifest.to_dict()
	var bulk: Array = []
	for i in range(ReplayManifest.MAX_EVENTS + 1):
		bulk.append({"kind": "go_code", "tick": 1, "seq": i, "code": "alpha"})
	d["input_stream"] = bulk
	_expect(_has(ReplayManifest.validate(d), "event_count"), "event_count_cap", failures)
	_expect(ReplayManifest.safe_id("../evil") == "", "path_traversal", failures)
	_expect(ReplayManifest.safe_id("op01_replay") == "op01_replay", "safe_filename", failures)
	for issue in failures:
		print("[REPLAY] FAIL negative %s" % issue)
	return failures.size()
