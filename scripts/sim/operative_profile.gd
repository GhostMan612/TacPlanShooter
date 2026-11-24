# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name OperativeProfile
extends RefCounted


const TRAIT_NAMES: Array[StringName] = [&"aggression", &"leadership", &"self_control", &"stamina", &"teamwork"]
const SKILL_NAMES: Array[StringName] = [&"demolitions", &"electronics", &"firearms", &"grenades", &"stealth"]


enum Health { HEALTHY, WOUNDED, KIA }


var values: Dictionary = {}
var health: Health = Health.HEALTHY
var codename: StringName = &""


func get_trait(name: StringName) -> int:
	return int(values.get(name, 50))


func set_trait(name: StringName, v: int) -> void:
	values[name] = clamp(int(v), 0, 100)


func get_skill(name: StringName) -> int:
	return int(values.get(name, 50))


func set_skill(name: StringName, v: int) -> void:
	values[name] = clamp(int(v), 0, 100)


func set_health(h: Health) -> void:
	health = h


func is_alive() -> bool:
	return health != Health.KIA
