# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name SimOperative
extends RefCounted

var id: int = -1
var pos := Vector2.ZERO
var floor_idx: int = 0
var facing_deg := 0.0
var stance := &"normal"
var hp := 100
var queue: CommandQueue = null
var cooldown_ticks := 0
var field_of_fire_deg := -1
var active_path := PackedVector2Array()
var path_index := 0
var wait_code := &""
var done := false
var move_carry := 0.0
var halted := false
var move_blocked_from := 0
var skills: Dictionary = {}
var armor_class: StringName = &"light"
var health: StringName = &"healthy"
var mode_name: StringName = &""
var heartbeat_radius: int = 0
var faction_id: int = 0
var owner_peer_id: int = -1


func speed_cells_per_sec() -> float:
	return SimConstants.BASE_SPEED_CELLS_PER_SEC * float(SimConstants.STANCE_SPEED_MULTIPLIERS.get(stance, 1.0))


func to_dict() -> Dictionary:
	var path_arr: Array = []
	for p in active_path:
		path_arr.append({"x": p.x, "y": p.y})
	return {
		"id": id,
		"px": pos.x,
		"py": pos.y,
		"floor": floor_idx,
		"facing": facing_deg,
		"stance": String(stance),
		"hp": hp,
		"cooldown": cooldown_ticks,
		"fof": field_of_fire_deg,
		"path": path_arr,
		"path_index": path_index,
		"wait": String(wait_code),
		"done": done,
		"carry": move_carry,
		"halted": halted,
		"blocked": move_blocked_from,
		"skills": _skills_list(),
		"armor_class": String(armor_class),
		"health": String(health),
		"mode_name": String(mode_name),
		"heartbeat_radius": heartbeat_radius,
		"faction_id": faction_id,
		"owner_peer_id": owner_peer_id,
		"queue": queue.to_dict() if queue != null else {},
	}


static func from_dict(d: Dictionary) -> SimOperative:
	var o := SimOperative.new()
	o.id = int(d.get("id", -1))
	o.pos = Vector2(float(d.get("px", 0.0)), float(d.get("py", 0.0)))
	o.floor_idx = int(d.get("floor", 0))
	o.facing_deg = float(d.get("facing", 0.0))
	o.stance = StringName(String(d.get("stance", "normal")))
	o.hp = int(d.get("hp", 100))
	o.cooldown_ticks = int(d.get("cooldown", 0))
	o.field_of_fire_deg = int(d.get("fof", -1))
	var path_arr: Array = d.get("path", [])
	var p := PackedVector2Array()
	for pd in path_arr:
		p.append(Vector2(float(pd.get("x", 0.0)), float(pd.get("y", 0.0))))
	o.active_path = p
	o.path_index = int(d.get("path_index", 0))
	o.wait_code = StringName(String(d.get("wait", "")))
	o.done = bool(d.get("done", false))
	o.move_carry = float(d.get("carry", 0.0))
	o.halted = bool(d.get("halted", false))
	o.move_blocked_from = int(d.get("blocked", 0))
	for pair in d.get("skills", []):
		o.skills[StringName(String(pair[0]))] = int(pair[1])
	o.armor_class = StringName(String(d.get("armor_class", "light")))
	o.health = StringName(String(d.get("health", "healthy")))
	o.mode_name = StringName(String(d.get("mode_name", "")))
	o.heartbeat_radius = int(d.get("heartbeat_radius", 0))
	o.faction_id = int(d.get("faction_id", 0))
	o.owner_peer_id = int(d.get("owner_peer_id", -1))
	o.queue = CommandQueue.from_dict(d.get("queue", {}))
	return o


func is_alive() -> bool:
	return hp > 0 and health != &"kia"


func _skills_list() -> Array:
	var arr := []
	for k in skills.keys():
		arr.append([String(k), int(skills[k])])
	arr.sort()
	return arr
