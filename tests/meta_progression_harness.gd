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
	failures += _test_save_load()
	failures += _test_xp_roles()
	failures += _test_armory_tree()
	failures += _test_pvp_budget()
	failures += _test_mission_grading()
	print("[HARNESS] RESULT %s failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _test_mission_grading() -> int:
	var w := SimWorld.new()
	w.setup(GreyboxMap.build_default(), 1337)
	var g := MissionGrading.new()
	var rp := int(g.grade(w, true)["rp"])
	var xp := int(g.grade(w, true)["xp"])
	var ok := rp == MissionGrading.RP_OBJECTIVE + MissionGrading.RP_ZERO_CASUALTIES
	ok = ok and int(g.grade(w, false)["rp"]) == MissionGrading.RP_ZERO_CASUALTIES
	ok = ok and xp == rp
	print("[HARNESS] mp_mission_grading %s (rp=%d)" % ["PASS" if ok else "FAIL", rp])
	return 0 if ok else 1


func _test_save_load() -> int:
	var s := ProgressionSave.new()
	var p := UnitProfile.new()
	p.operative_id = 1
	p.earn_xp(100)
	s.profiles.append(p)
	var json := s.save_json()
	var s2 := ProgressionSave.new()
	var ok: bool = s2.load_json(json) and s2.profiles.size() == 1 and s2.profiles[0].xp == 100
	print("[HARNESS] mp_save_load %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_xp_roles() -> int:
	var p := UnitProfile.new()
	p.operative_id = 2
	var ok := p.xp == 0
	p.earn_xp(50)
	p.assign_role(UnitProfile.Role.MEDIC_RESCUE)
	ok = ok and p.xp == 50 and p.role == int(UnitProfile.Role.MEDIC_RESCUE)
	print("[HARNESS] mp_xp_roles %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_armory_tree() -> int:
	var a := ArmoryCatalog.new()
	a.unlock(&"weapon_smg_standard")
	var ok := a.is_unlocked(&"weapon_smg_standard") and not a.is_unlocked(&"vehicle_raid_van")
	a.unlock(&"vehicle_raid_van")
	ok = ok and a.is_unlocked(&"vehicle_raid_van")
	print("[HARNESS] mp_armory_tree %s" % ("PASS" if ok else "FAIL"))
	return 0 if ok else 1


func _test_pvp_budget() -> int:
	var a := ArmoryCatalog.new()
	for item in a.WEAPONS:
		a.unlock(item)
	var p := UnitProfile.new()
	for item in a.WEAPONS:
		p.equip(item)
	var screen := ArmoryScreen.new()
	screen.armory = a
	var ok := screen.valid_for_pvp(p)
	screen.free()
	print("[HARNESS] mp_pvp_budget %s (points=%d max=%d)" % ["PASS" if ok else "FAIL", p.loadout_points(), a.STANDARDIZED_LOADOUT_POINTS])
	return 0 if ok else 1
