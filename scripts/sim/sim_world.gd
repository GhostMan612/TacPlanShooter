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
var go_code_stream: Array[Dictionary] = []
var operatives: Array[SimOperative] = []
var enemy_actors: Dictionary = {}
var pending: Array[Dictionary] = []
var entities: Array[SimEntity] = []
var entity_seq := 0
var journal: Array[Dictionary] = []
var override_stream: Array[OverrideCommand] = []
var tapin_player_cooldown: int = 0
var tapin_unit_cooldowns: Dictionary = {}
var tapin_bursts: Dictionary = {}
var tapin_points: int = SimConstants.TAPIN_COMMAND_POINTS_MAX
var door_system := DoorSystem.new()
var ballistics := BallisticsSuppression.new()
var drones: Array[SimDrone] = []
var vehicles: Array[SimVehicle] = []
var ai := AiCoordinator.new()


func setup(p_map: GreyboxMap, seed_value: int) -> void:
	map = GreyboxMap.from_dict(p_map.to_dict())
	rng.seed = seed_value
	tick = 0
	go_codes_issued.clear()
	go_code_stream.clear()
	operatives.clear()
	pending.clear()
	journal.clear()
	entities.clear()
	entity_seq = 0
	override_stream.clear()
	tapin_points = SimConstants.TAPIN_COMMAND_POINTS_MAX
	tapin_player_cooldown = 0
	tapin_unit_cooldowns.clear()
	tapin_bursts.clear()
	drones.clear()
	vehicles.clear()
	enemy_actors.clear()
	ai = AiCoordinator.new()
	door_system = DoorSystem.new()
	ballistics = BallisticsSuppression.new()


func add_operative(id: int, spawn_cell: Vector2i, commands: Array[AgentCommand]) -> SimOperative:
	var o := SimOperative.new()
	o.id = id
	o.pos = Vector2(spawn_cell) + Vector2(0.5, 0.5)
	o.queue = CommandQueue.new(id)
	o.queue.reset(commands)
	operatives.append(o)
	return o


func add_enemy(id: int, spawn_cell: Vector2i, archetype: StringName, facing_deg: float = 0.0) -> SimOperative:
	var o := SimOperative.new()
	o.id = id
	o.pos = Vector2(spawn_cell) + Vector2(0.5, 0.5)
	o.facing_deg = facing_deg
	o.queue = CommandQueue.new(id)
	o.faction_id = 1
	enemy_actors[id] = o
	ai.add_enemy(id, archetype)
	return o


func apply_override(oc: OverrideCommand) -> void:
	if tapin_player_cooldown > 0:
		return
	var ucd: int = int(tapin_unit_cooldowns.get(oc.op_id, 0))
	if ucd > 0:
		return
	if tapin_points <= 0:
		return
	tapin_points -= 1
	tapin_player_cooldown = SimConstants.TAPIN_HANDOFF_TICKS
	tapin_unit_cooldowns[oc.op_id] = SimConstants.TAPIN_UNIT_COOLDOWN_TICKS
	var burst: int = int(tapin_bursts.get(oc.op_id, 0))
	if burst >= SimConstants.TAPIN_MAX_BURST_TICKS:
		return
	tapin_bursts[oc.op_id] = burst + 1
	override_stream.append(OverrideCommand.from_dict(oc.to_dict()))
	journal.append({"t": oc.tick, "ev": &"override", "op": oc.op_id})


func release_tapin(op_id: int) -> void:
	tapin_player_cooldown = SimConstants.TAPIN_COOLDOWN_TICKS
	tapin_unit_cooldowns[op_id] = SimConstants.TAPIN_UNIT_COOLDOWN_TICKS


func _process_overrides() -> void:
	for oc in override_stream:
		if oc.tick != tick:
			continue
		for o in operatives:
			if o.id != oc.op_id or not o.is_alive():
				continue
			if oc.aim_deg != 0.0:
				o.facing_deg = oc.aim_deg
			if oc.move_dir.length() > 0.000001:
				o.pos += oc.move_dir.normalized() * SimConstants.BASE_SPEED_CELLS_PER_SEC * o.speed_cells_per_sec() * (1.0 / 60.0)


func schedule_go_code(code: StringName) -> void:
	go_code_stream.append({"t": tick + 1, "code": String(code)})


func _process_go_code_stream() -> void:
	for e in go_code_stream:
		if int(e["t"]) == tick:
			issue_go_code(StringName(String(e["code"])))


func issue_go_code(code: StringName) -> void:
	if go_codes_issued.has(code):
		return
	go_codes_issued[code] = true
	journal.append({"t": tick, "ev": &"go_issued", "code": String(code)})


func heartbeat_radius_of(o: SimOperative) -> int:
	return int(o.heartbeat_radius)


func sound_event(cell: Vector2i, kind: StringName) -> void:
	ai.blackboard.record_acoustic(cell, kind, tick)


func step() -> void:
	tick += 1
	_process_go_code_stream()
	ai.step_all()
	ai.update_threats(self)
	if tapin_player_cooldown > 0:
		tapin_player_cooldown -= 1
	_tick_down_tapin()
	_tick_drones()
	_process_overrides()
	_process_pending()
	_step_entities()
	for o in operatives:
		_step_operative(o)


func _tick_drones() -> void:
	for d in drones:
		if not d.destroyed:
			d.battery -= 1
			if d.battery <= 0:
				d.destroyed = true


func spawn_drone(owner_op: int) -> SimDrone:
	var d := SimDrone.new()
	d.id = drones.size()
	d.owner_op = owner_op
	d.kind = SimDrone.Class.GROUND_RECON
	drones.append(d)
	return d


func destroy_drone(id: int) -> void:
	for d in drones:
		if d.id == id:
			d.destroyed = true


func _tick_down_tapin() -> void:
	for k in tapin_unit_cooldowns.keys():
		tapin_unit_cooldowns[k] = int(tapin_unit_cooldowns[k]) - 1
	for k in tapin_bursts.keys():
		tapin_bursts[k] = int(tapin_bursts[k]) - 1


func all_done() -> bool:
	for o in operatives:
		if not o.done:
			return false
	return true


func _overrides_arr() -> Array:
	var arr := []
	for oc in override_stream:
		arr.append(oc.to_dict())
	return arr


func snapshot_data() -> Dictionary:
	var issued_arr: Array[String] = []
	for k in go_codes_issued.keys():
		issued_arr.append(String(k))
	issued_arr.sort()
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
	var enemies_arr: Array = []
	var enemy_ids: Array = enemy_actors.keys()
	enemy_ids.sort()
	for id in enemy_ids:
		enemies_arr.append((enemy_actors[id] as SimOperative).to_dict())
	var drones_arr: Array = []
	for drone in drones:
		drones_arr.append(drone.to_dict())
	var vehicles_arr: Array = []
	for vehicle in vehicles:
		vehicles_arr.append(vehicle.to_dict())
	return {
		"tick": tick,
		"rng_seed": rng.seed,
		"rng_state": rng.state,
		"go_issued": issued_arr,
		"map": map.to_dict(),
		"pending": pending_arr,
		"entities": entities_arr,
		"override_stream": _overrides_arr(),
		"operatives": ops_arr,
		"enemy_actors": enemies_arr,
		"ai": ai.to_dict(),
		"drones": drones_arr,
		"vehicles": vehicles_arr,
		"door_system": door_system.to_array(),
		"suppression": _int_dict_pairs(ballistics.suppression),
		"journal": journal.duplicate(true),
		"entity_seq": entity_seq,
		"go_code_stream": go_code_stream.duplicate(true),
		"tapin_points": tapin_points,
		"tapin_player_cooldown": tapin_player_cooldown,
		"tapin_unit_cooldowns": _int_dict_pairs(tapin_unit_cooldowns),
		"tapin_bursts": _int_dict_pairs(tapin_bursts),
	}


static func _int_dict_pairs(d: Dictionary) -> Array:
	var keys: Array = d.keys()
	keys.sort()
	var out: Array = []
	for k in keys:
		out.append([int(k), int(d[k])])
	return out


static func _pairs_to_int_dict(pairs: Array) -> Dictionary:
	var out := {}
	for p in pairs:
		out[int(p[0])] = int(p[1])
	return out


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
	override_stream.clear()
	for od in d.get("override_stream", []):
		override_stream.append(OverrideCommand.from_dict(od))
	entity_seq = int(d.get("entity_seq", entities.size()))
	go_code_stream.clear()
	for g in d.get("go_code_stream", []):
		go_code_stream.append({"t": int(g["t"]), "code": String(g["code"])})
	tapin_points = int(d.get("tapin_points", SimConstants.TAPIN_COMMAND_POINTS_MAX))
	tapin_player_cooldown = int(d.get("tapin_player_cooldown", 0))
	tapin_unit_cooldowns = _pairs_to_int_dict(d.get("tapin_unit_cooldowns", []))
	tapin_bursts = _pairs_to_int_dict(d.get("tapin_bursts", []))

	drones.clear()
	for dd in d.get("drones", []):
		drones.append(SimDrone.from_dict(dd))
	vehicles.clear()
	for vd in d.get("vehicles", []):
		vehicles.append(SimVehicle.from_dict(vd))
	enemy_actors.clear()
	for ed in d.get("enemy_actors", []):
		var enemy := SimOperative.from_dict(ed)
		enemy_actors[enemy.id] = enemy
	ai = AiCoordinator.from_dict(d.get("ai", {}))
	door_system = DoorSystem.from_array(d.get("door_system", []))
	ballistics = BallisticsSuppression.new()
	ballistics.suppression = _pairs_to_int_dict(d.get("suppression", []))


func state_hash() -> String:
	return JSON.stringify(snapshot_data(), "", true, true).sha256_text()


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
	if o.done or o.halted or not o.is_alive():
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
		journal.append({"t": tick, "ev": &"move_end", "op": o.id, "px": o.pos.x, "py": o.pos.y})
		o.queue.advance_cursor()
		var nxt := o.queue.peek_next()
		o.move_carry = remaining if nxt != null and nxt.command_type == AgentCommand.CommandType.MOVE_TO_CELL else 0.0
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
		if p == o or p.done or not p.is_alive():
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
