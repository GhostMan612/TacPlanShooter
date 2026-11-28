# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name ReplayPlayer
extends RefCounted


static func normalize_event(e: Variant) -> Dictionary:
	if e is Dictionary:
		var d := e as Dictionary
		if d.has("kind"):
			return d.duplicate(true)
		if d.has("t") and d.has("code"):
			return {
				"kind": ReplayManifest.GO_CODE_KIND,
				"tick": int(d["t"]),
				"seq": 0,
				"code": String(d["code"]),
			}
		if d.has("tick") and d.has("op_id"):
			return {
				"kind": ReplayManifest.OVERRIDE_KIND,
				"tick": int(d["tick"]),
				"seq": 0,
				"data": d.duplicate(true),
			}
	elif e is OverrideCommand:
		var oc := e as OverrideCommand
		return {
			"kind": ReplayManifest.OVERRIDE_KIND,
			"tick": oc.tick,
			"seq": 0,
			"data": oc.to_dict(),
		}
	return {}


static func events_for_scrub(go_codes: Array, overrides: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in go_codes:
		var n := normalize_event(e)
		if not n.is_empty():
			out.append(n)
	for e in overrides:
		var n := normalize_event(e)
		if not n.is_empty():
			out.append(n)
	out.sort_custom(func(a, b):
		var ta := int(a.get("tick", 0))
		var tb := int(b.get("tick", 0))
		if ta != tb:
			return ta < tb
		return int(a.get("seq", 0)) < int(b.get("seq", 0))
	)
	return out


static func replay_into(world: SimWorld, snapshot_data: Dictionary, events: Array, target_tick: int) -> bool:
	world.restore_from_data(snapshot_data)
	var ordered: Array[Dictionary] = []
	for e in events:
		var n := normalize_event(e)
		if not n.is_empty():
			ordered.append(n)
	ordered.sort_custom(func(a, b):
		var ta := int(a.get("tick", 0))
		var tb := int(b.get("tick", 0))
		if ta != tb:
			return ta < tb
		return int(a.get("seq", 0)) < int(b.get("seq", 0))
	)
	var target := maxi(0, target_tick)
	for e in ordered:
		var t := int(e.get("tick", 0))
		if t > target:
			break
		if t < 1:
			return false
		while world.tick < t - 1:
			world.step()
		if world.tick != t - 1:
			return false
		if String(e.get("kind", "")) == ReplayManifest.GO_CODE_KIND:
			world.schedule_go_code(StringName(String(e.get("code", ""))))
		else:
			world.apply_override(OverrideCommand.from_dict(e.get("data", {})))
	while world.tick < target:
		world.step()
	return true


static func manifest_events(manifest: ReplayManifest) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in manifest.input_stream:
		out.append(e.duplicate(true))
	return out


static func journal_digest_for(world: SimWorld) -> String:
	return ReplayManifest.canonical(world.journal).sha256_text()


static func verify(manifest: ReplayManifest) -> Dictionary:
	var reasons := ReplayManifest.validate(manifest.to_dict())
	if not reasons.is_empty():
		return {
			"ok": false,
			"reason": ",".join(reasons),
			"expected": "",
			"actual": "",
			"ticks": 0,
		}
	if not manifest.integrity_ok():
		return {
			"ok": false,
			"reason": "integrity_hash",
			"expected": manifest.final_state_hash,
			"actual": "",
			"ticks": 0,
		}
	var world := SimWorld.new()
	if not replay_into(world, manifest.initial_snapshot, manifest.input_stream, manifest.terminal_tick):
		return {
			"ok": false,
			"reason": "event_ordering",
			"expected": manifest.final_state_hash,
			"actual": "",
			"ticks": world.tick,
		}
	var actual := world.state_hash()
	var digest := journal_digest_for(world)
	var ok := actual == manifest.final_state_hash and digest == manifest.journal_digest
	return {
		"ok": ok,
		"reason": "" if ok else "state_hash",
		"expected": manifest.final_state_hash,
		"actual": actual,
		"journal_expected": manifest.journal_digest,
		"journal_actual": digest,
		"ticks": world.tick,
	}
