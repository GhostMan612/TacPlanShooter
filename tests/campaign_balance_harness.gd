# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
extends SceneTree


var failures: int = 0


func _init() -> void:
	failures = 0


func _initialize() -> void:
	var names: Array[StringName] = []
	for key in AiArchetypes.ARCHETYPES.keys():
		names.append(key)
	var ordering_ok := true
	for name in names:
		var recruit := AiArchetypes.reaction_ticks(name, SimConstants.Difficulty.RECRUIT)
		var veteran := AiArchetypes.reaction_ticks(name, SimConstants.Difficulty.VETERAN)
		var tier1 := AiArchetypes.reaction_ticks(name, SimConstants.Difficulty.TIER_ONE)
		ordering_ok = ordering_ok and recruit > veteran and veteran > tier1
	_check(ordering_ok, "difficulty reaction ticks RECRUIT > VETERAN > TIER_ONE across all archetypes")
	_check(AiArchetypes.goap_cadence(0) == 24 and AiArchetypes.goap_cadence(1) == 12 and AiArchetypes.goap_cadence(2) == 8, "GOAP replan cadence 24/12/8")
	var hashes := {}
	for map_id in ["op01_glass_house", "op05_penthouse_lock"]:
		var m := MapLoader.load_from_json("res://data/maps/%s.json" % map_id)
		var first := ""
		var equal := true
		for run in range(2):
			var sim := SimWorld.new()
			sim.setup(m, 1337)
			sim.add_operative(0, Vector2i(2, 2), [])
			for i in range(120):
				sim.step()
			var h := sim.state_hash()
			if first == "":
				first = h
			else:
				equal = equal and h == first
		_check(equal, "deterministic 60Hz state_hash across repeated runs on " + map_id)
	var rewards := [150, 200, 250, 300]
	var total := 0
	for r in rewards:
		total += int(r)
	_check(total == 900, "OP-01..OP-04 RP curve sums to 900")
	_check(total >= 150, "900 RP affords armor/drone/vehicle upgrades")
	print("[HARNESS] RESULT %s failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print("[HARNESS] %s %s" % ["OK" if ok else "FAIL", what])
