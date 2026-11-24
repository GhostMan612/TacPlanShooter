# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name SimWorld
extends RefCounted

const DT := 1.0 / 60.0

var map: GreyboxMap = null
var rng := RandomNumberGenerator.new()
var tick := 0
var go_codes_issued := {}
var operatives: Array[SimOperative] = []
var pending: Array[Dictionary] = []
var entities: Array[SimEntity] = []
var entity_seq := 0
var journal: Array[Dictionary] = []


func setup(p_map: GreyboxMap, seed_value: int) -> void:
	map = p_map
	rng.seed = seed_value
	tick = 0
	go_codes_issued.clear()
	operatives.clear()
	pending.clear()
	journal.clear()


func add_operative(id: int, spawn_cell: Vector2i, commands: Array[AgentCommand]) -> void:
	var o := SimOperative.new()
	o.id = id
	o.pos = Vector2(spawn_cell) + Vector2(0.5, 0.5)
	o.queue = CommandQueue.new(id)
	o.queue.reset(commands)
	operatives.append(o)


func issue_go_code(code: StringName) -> void:
	if go_codes_issued.has(code):
		return
	go_codes_issued[code] = true
	journal.append({"t": tick, "ev": &"go_issued", "code": String(code)})


func step() -> void:
	tick += 1
	_process_pending()
	_step_entities()
	for o in operatives:
		_step_operative(o)


func all_done() -> bool:
	for o in operatives:
		if not o.done:
			return false
	return true


func snapshot_data() -> Dictionary:
	var issued_arr: Array = []
	for k in go_codes_issued.keys():
		issued_arr.append(String(k))
	var ops_arr: Array = []
	for o in operatives:
		ops_arr.append(o.to_dict())
	var pending_arr: Array = []
	for e in pending:
		pending_arr.append({
			"due": int(e["due"]),
			"cx": int(e["cx"]),
			"cy": int(e["cy"]),
			"op": int(e["op"]),
		})
	var entities_arr: Array = []
	for e in entities:
		entities_arr.append(e.to_dict())
	return {
		"tick": tick,
		"rng_seed": rng.seed,
		"rng_state": rng.state,
		"go_issued": issued_arr,
		"map": map.to_dict(),
		"pending": pending_arr,
		"entities": entities_arr,
		"operatives": ops_arr,
		"journal": journal.duplicate(true),
	}


func restore_from_data(d: Dictionary) -> void:
	tick = int(d["tick"])
	rng.seed = int(d["rng_seed"])
	rng.state = int(d["rng_state"])
	go_codes_issued.clear()
	for s in d.get("go_issued", []):
		go_codes_issued[StringName(String(s))] = true
	map = GreyboxMap.from_dict(d.get("map", {}))
	pending.clear()
	for e in d.get("pending", []):
		pending.append({
			"due": int(e["due"]),
			"cx": int(e["cx"]),
			"cy": int(e["cy"]),
			"op": int(e["op"]),
		})
	entities.clear()
	for ed in d.get("entities", []):
		entities.append(SimEntity.from_dict(ed))
	operatives.clear()
	for od in d.get("operatives", []):
		operatives.append(SimOperative.from_dict(od))
	journal = d.get("journal", []).duplicate(true)


func state_hash() -> String:
	var parts := PackedStringArray()
	parts.append("T%d" % tick)
	parts.append("R%d|%d" % [int(rng.seed), int(rng.state)])
	for o in operatives:
		var path_parts := PackedStringArray()
		for p in o.active_path:
			var pv: Vector2 = p
			path_parts.append("%.9f,%.9f" % [pv.x, pv.y])
		parts.append("O%d|%.9f|%.9f|%d|%s|%d|%d|%d|%s|%d|%d|%d|%.9f|%d|%d|%s" % [
			o.id,
			o.pos.x,
			o.pos.y,
			int(round(o.facing_deg)),
			String(o.stance),
			o.hp,
			o.cooldown_ticks,
			o.field_of_fire_deg,
			String(o.wait_code),
			o.queue.cursor,
			o.path_index,
			1 if o.done else 0,
			o.move_carry,
			1 if o.halted else 0,
			int(o.move_blocked_from),
			";".join(path_parts),
		])
	for o in operatives:
		var ks := PackedStringArray()
		for k in o.skills.keys():
			ks.append("%s=%d" % [String(k), int(o.skills[k])])
		ks.sort()
		parts.append("X%d|%s|%s|%s|%s|%d" % [
			o.id,
			String(o.mode_name),
			String(o.health),
			String(o.armor_class),
			";".join(ks),
			o.heartbeat_radius,
		])
	var door_parts := PackedStringArray()
	for k in map.door_open.keys():
		door_parts.append("%d,%d=%s" % [int(k.x), int(k.y), "1" if bool(map.door_open[k]) else "0"])
	door_parts.sort()
	parts.append("D" + ";".join(door_parts))
	var gc := PackedStringArray()
	for k in go_codes_issued.keys():
		gc.append(String(k))
	gc.sort()
	parts.append("G" + ";".join(gc))
	for e in pending:
		parts.append("P" + _canon(e))
	var ent_parts := PackedStringArray()
	for e in entities:
		ent_parts.append("E%d|%.9f|%.9f|%d|%d|%d" % [e.id, e.pos.x, e.pos.y, e.spawned_tick, e.due_tick, e.kind])
	ent_parts.sort()
	parts.append("Q" + ";".join(ent_parts))
	for e in journal:
		parts.append("J" + _canon(e))
	return "\n".join(parts).sha256_text()


static func _canon(d: Dictionary) -> String:
	var keys := d.keys()
	keys.sort()
	var out := PackedStringArray()
	for k in keys:
		var v: Variant = d[k]
		if typeof(v) == TYPE_FLOAT:
			out.append("%s=%.9f" % [str(k), v])
		else:
			out.append("%s=%s" % [str(k), str(v)])
	return "{" + ",".join(out) + "}"


func _process_pending() -> void:
	var keep: Array[Dictionary] = []
	for e in pending:
		if int(e["due"]) <= tick:
			map.open_door(Vector2i(int(e["cx"]), int(e["cy"])))
			journal.append({"t": tick, "ev": &"breach_opened", "cx": int(e["cx"]), "cy": int(e["cy"])})
		else:
			keep.append(e)
	pending = keep


func _step_operative(o: SimOperative) -> void:
	if o.done or o.halted:
		return
	if o.cooldown_ticks > 0:
		o.cooldown_ticks -= 1
		return
	if o.wait_code != &"":
		if not go_codes_issued.has(o.wait_code):
			return
		o.wait_code = &""
		o.queue.advance_cursor()
		journal.append({"t": tick, "ev": &"go_released", "op": o.id})
	while true:
		var cmd := o.queue.peek_next()
		if cmd == null:
			o.done = true
			o.move_carry = 0.0
			journal.append({"t": tick, "ev": &"op_done", "op": o.id})
			return
		match cmd.command_type:
			AgentCommand.CommandType.SET_STANCE:
				o.stance = cmd.stance_name
				journal.append({"t": tick, "ev": &"stance_set", "op": o.id, "stance": String(cmd.stance_name)})
				o.queue.advance_cursor()
			AgentCommand.CommandType.SET_FIELD_OF_FIRE:
				o.field_of_fire_deg = cmd.bearing_deg
				o.facing_deg = cmd.bearing_deg
				journal.append({"t": tick, "ev": &"fof_set", "op": o.id, "bearing": cmd.bearing_deg})
				o.queue.advance_cursor()
			AgentCommand.CommandType.WAIT_GO_CODE:
				if go_codes_issued.has(cmd.go_code):
					o.queue.advance_cursor()
				else:
					o.wait_code = cmd.go_code
					o.move_carry = 0.0
					journal.append({"t": tick, "ev": &"go_wait", "op": o.id, "code": String(cmd.go_code)})
					return
			AgentCommand.CommandType.MOVE_TO_CELL:
				_step_move(o, cmd)
				return
			AgentCommand.CommandType.SET_MODE:
				o.mode_name = cmd.mode_name
				journal.append({"t": tick, "ev": &"mode_set", "op": o.id, "mode": String(cmd.mode_name)})
				o.queue.advance_cursor()
			AgentCommand.CommandType.PERFORM_ACTION:
				o.move_carry = 0.0
				_step_action(o, cmd)
				return
			_:
				o.queue.advance_cursor()


func _step_move(o: SimOperative, cmd: AgentCommand) -> void:
	if o.active_path.size() == 0:
		var start := GridUtil.cell_of(o.pos)
		var goal := cmd.target_cell
		if not map.in_bounds(goal):
			journal.append({"t": tick, "ev": &"move_rejected", "op": o.id, "tx": int(goal.x), "ty": int(goal.y)})
			o.queue.advance_cursor()
			return
		var path := GridPathfinder.find_path(map, start, goal)
		if path.size() <= 1:
			o.queue.advance_cursor()
			return
		var centers := PackedVector2Array()
		for c in path:
			centers.append(Vector2(c) + Vector2(0.5, 0.5))
		o.active_path = centers
		o.path_index = 0
		journal.append({"t": tick, "ev": &"move_start", "op": o.id, "tx": int(goal.x), "ty": int(goal.y)})
	var speed := o.speed_cells_per_sec()
	var remaining := speed * DT + o.move_carry
	o.move_carry = 0.0
	var committed := false
	while remaining > 0.0 and o.path_index < o.active_path.size() - 1:
		var target := o.active_path[o.path_index + 1]
		var to_target := target - o.pos
		var dist := to_target.length()
		if dist <= 0.0:
			o.path_index += 1
			continue
		var cand: Vector2
		var next_idx: int
		var rem_after: float
		if dist <= remaining:
			cand = target
			next_idx = o.path_index + 1
			rem_after = remaining - dist
		else:
			cand = o.pos + to_target * (remaining / dist)
			next_idx = o.path_index
			rem_after = 0.0
		var cell := GridUtil.cell_of(cand)
		if not map.in_bounds(cell) or map.is_solid(cell):
			if o.move_blocked_from == 0:
				o.move_blocked_from = tick
				journal.append({"t": tick, "ev": &"move_blocked", "op": o.id, "x": cand.x, "y": cand.y})
			break
		o.pos = cand
		o.path_index = next_idx
		remaining = rem_after
		var heading := to_target.normalized()
		committed = true
		if o.move_blocked_from != 0:
			journal.append({"t": tick, "ev": &"move_unblocked", "op": o.id, "x": cand.x, "y": cand.y})
			o.move_blocked_from = 0
		if o.field_of_fire_deg < 0:
			o.facing_deg = rad_to_deg(heading.angle())
	if committed and o.path_index >= o.active_path.size() - 1:
		o.active_path = PackedVector2Array()
		o.move_carry = 0.0
		journal.append({"t": tick, "ev": &"move_end", "op": o.id, "px": o.pos.x, "py": o.pos.y})
		o.queue.advance_cursor()
	if committed:
		_check_collision(o)


func _step_action(o: SimOperative, cmd: AgentCommand) -> void:
	var target := cmd.target_cell
	var target_center := Vector2(target) + Vector2(0.5, 0.5)
	var in_range := o.pos.distance_to(target_center) <= float(SimConstants.ACTION_MAX_RANGE_CELLS)
	var is_door := map.door_cells.has(target)
	var valid := map.in_bounds(target) and in_range
	if cmd.action_kind == AgentCommand.ActionKind.BREACH_CHARGE:
		valid = valid and is_door
	else:
		valid = valid and not map.is_solid(target)
	if not valid:
		journal.append({
			"t": tick,
			"ev": &"action_rejected",
			"op": o.id,
			"kind": int(cmd.action_kind),
			"tx": int(target.x),
			"ty": int(target.y),
		})
		o.queue.advance_cursor()
		return
	var fuse := SimConstants.ACTION_FUSE_TICKS
	o.cooldown_ticks = SimConstants.ACTION_COOLDOWN_TICKS
	journal.append({
		"t": tick,
		"ev": &"action",
		"op": o.id,
		"kind": int(cmd.action_kind),
		"tx": int(target.x),
		"ty": int(target.y),
		"fuse": fuse,
	})
	if cmd.action_kind == AgentCommand.ActionKind.BREACH_CHARGE:
		pending.append({
			"due": tick + fuse,
			"cx": int(target.x),
			"cy": int(target.y),
			"op": o.id,
		})
	elif cmd.action_kind != AgentCommand.ActionKind.NONE:
		var e := SimEntity.new()
		e.id = entity_seq
		e.kind = int(cmd.action_kind)
		e.op_id = o.id
		e.pos = target_center
		e.spawned_tick = tick
		e.due_tick = tick + SimConstants.ACTION_ENTITY_LIFE_TICKS
		entities.append(e)
		entity_seq += 1
		journal.append({"t": tick, "ev": &"entity_spawned", "id": e.id, "op": o.id, "kind": e.kind, "tx": int(target.x), "ty": int(target.y)})
	o.queue.advance_cursor()


func _step_entities() -> void:
	var keep: Array[SimEntity] = []
	for e in entities:
		if e.done or e.due_tick > tick:
			keep.append(e)
			continue
		e.done = true
		_apply_entity_effect(e)
		journal.append({"t": tick, "ev": &"entity_effect", "id": e.id, "op": e.op_id, "kind": e.kind, "tx": int(e.pos.x), "ty": int(e.pos.y)})
	entities = keep


func _apply_entity_effect(e: SimEntity) -> void:
	if e.kind != int(AgentCommand.ActionKind.FRAG):
		return
	for op in operatives:
		if op.id == e.op_id or op.done:
			continue
		if op.pos.distance_to(e.pos) <= float(SimConstants.FRAG_RADIUS_CELLS):
			op.hp -= SimConstants.FRAG_DAMAGE


func _check_collision(o: SimOperative) -> void:
	var plan := _collision_plan(o)
	for p in operatives:
		if p == o or p.done:
			continue
		if _polyline_intersects(plan, _collision_plan(p)):
			o.halted = true
			p.halted = true
			journal.append({"t": tick, "ev": &"collision_halt", "op": o.id})
			journal.append({"t": tick, "ev": &"collision_halt", "op": p.id})


static func _collision_plan(o: SimOperative) -> Array[Vector2]:
	var out: Array[Vector2] = [o.pos]
	for i in range(o.path_index + 1, o.active_path.size()):
		out.append(o.active_path[i])
	return out


static func _polyline_intersects(a: Array[Vector2], b: Array[Vector2]) -> bool:
	if a.size() == 0 or b.size() == 0:
		return false
	if a.size() == 1:
		for i in range(b.size() - 1):
			if _point_on_segment(a[0], b[i], b[i + 1]):
				return true
	if b.size() == 1:
		for i in range(a.size() - 1):
			if _point_on_segment(b[0], a[i], a[i + 1]):
				return true
	for i in range(a.size() - 1):
		for j in range(b.size() - 1):
			if _segments_intersect(a[i], a[i + 1], b[j], b[j + 1]):
				return true
	return false


static func _point_on_segment(p: Vector2, a: Vector2, b: Vector2) -> bool:
	if (b - a).length_squared() < 0.0001:
		return p.distance_to(a) < 0.001
	var cross := (p - a).cross(b - a)
	if absf(cross) > 1e-4:
		return false
	var dot := (p - a).dot(b - a)
	return dot >= -1e-4 and dot <= (b - a).length_squared() + 1e-4


static func _segments_intersect(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> bool:
	var d1 := (p2 - p1).cross(p3 - p1)
	var d2 := (p2 - p1).cross(p4 - p1)
	var d3 := (p4 - p3).cross(p1 - p3)
	var d4 := (p4 - p3).cross(p2 - p3)
	if ((d1 > 0.0 and d2 < 0.0) or (d1 < 0.0 and d2 > 0.0)) and ((d3 > 0.0 and d4 < 0.0) or (d3 < 0.0 and d4 > 0.0)):
		return true
	if absf(d1) <= 1e-9 and _point_on_segment(p3, p1, p2):
		return true
	if absf(d2) <= 1e-9 and _point_on_segment(p4, p1, p2):
		return true
	if absf(d3) <= 1e-9 and _point_on_segment(p1, p3, p4):
		return true
	if absf(d4) <= 1e-9 and _point_on_segment(p2, p3, p4):
		return true
	return false
