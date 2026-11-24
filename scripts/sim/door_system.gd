# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name DoorSystem
extends RefCounted


enum State { OPEN, CLOSED_UNLOCKED, LOCKED, BARRICADED, BREACHED_DESTROYED }


var doors: Dictionary = {}


func add_door(cell: Vector2i) -> void:
	doors[cell] = {"state": int(State.CLOSED_UNLOCKED), "lock_level": 0}


func has(cell: Vector2i) -> bool:
	return doors.has(cell)


func state(cell: Vector2i) -> int:
	if not doors.has(cell):
		return int(State.OPEN)
	return int(doors[cell].get("state", int(State.OPEN)))


func set_lock(cell: Vector2i, level: int) -> void:
	if doors.has(cell):
		doors[cell]["lock_level"] = clamp(int(level), 0, 2)


func open(cell: Vector2i) -> void:
	doors[cell] = {"state": int(State.OPEN), "lock_level": 0}


func is_passable(cell: Vector2i) -> bool:
	var st := state(cell)
	return st == int(State.OPEN) or st == int(State.BREACHED_DESTROYED)


func breach(cell: Vector2i, method: StringName) -> bool:
	var st := state(cell)
	if st == int(State.BARRICADED):
		doors[cell] = {"state": int(State.BREACHED_DESTROYED), "lock_level": 0}
		return true
	if st == int(State.LOCKED):
		var lvl := int(doors[cell].get("lock_level", 0))
		if method == &"c4" or method == &"shotgun_breach" or (method == &"ram" and lvl <= 1):
			doors[cell] = {"state": int(State.BREACHED_DESTROYED), "lock_level": 0}
			return true
		return false
	doors[cell] = {"state": int(State.BREACHED_DESTROYED), "lock_level": 0}
	return true


func to_array() -> Array:
	var rows: Array = []
	for cell in GreyboxMap.sorted_cells(doors):
		var door: Dictionary = doors[cell]
		rows.append([cell.x, cell.y, int(door["state"]), int(door["lock_level"])])
	return rows


static func from_array(rows: Array) -> DoorSystem:
	var system := DoorSystem.new()
	for row in rows:
		var cell := Vector2i(int(row[0]), int(row[1]))
		system.doors[cell] = {"state": int(row[2]), "lock_level": int(row[3])}
	return system
