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
	o.pos = Vector2(spawn_cell)
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
	return {
		"tick": tick,
		"rng_seed": rng.seed,
		"rng_state": rng.state,
		"go_issued": issued_arr,
		"map": map.to_dict(),
		"pending": pending_arr,
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
		parts.append("O%d|%.9f|%.9f|%d|%s|%d|%d|%d|%s|%d|%d|%d|%.9f|%s" % [
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
			";".join(path_parts),
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
	if o.done:
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
			AgentCommand.CommandType.PERFORM_ACTION:
				o.move_carry = 0.0
				_step_action(o, cmd)
				return
			_:
				o.queue.advance_cursor()


func _step_move(o: SimOperative, cmd: AgentCommand) -> void:
	if o.active_path.size() == 0:
		o.active_path = PackedVector2Array([o.pos, Vector2(cmd.target_cell)])
		o.path_index = 0
		journal.append({"t": tick, "ev": &"move_start", "op": o.id, "tx": cmd.target_cell.x, "ty": cmd.target_cell.y})
	var remaining := o.speed_cells_per_sec() * DT + o.move_carry
	o.move_carry = 0.0
	var heading := Vector2.ZERO
	while remaining > 0.0 and o.path_index < o.active_path.size() - 1:
		var target := o.active_path[o.path_index + 1]
		var to_target := target - o.pos
		var dist := to_target.length()
		if dist <= remaining:
			o.pos = target
			o.path_index += 1
			remaining -= dist
			heading = to_target
		else:
			o.pos += to_target * (remaining / dist)
			remaining = 0.0
			heading = to_target
	if heading != Vector2.ZERO and o.field_of_fire_deg < 0:
		o.facing_deg = rad_to_deg(heading.angle())
	if o.path_index >= o.active_path.size() - 1:
		o.move_carry = remaining
		o.active_path = PackedVector2Array()
		o.path_index = 0
		journal.append({"t": tick, "ev": &"move_end", "op": o.id, "px": o.pos.x, "py": o.pos.y})
		o.queue.advance_cursor()


func _step_action(o: SimOperative, cmd: AgentCommand) -> void:
	var fuse := SimConstants.ACTION_FUSE_TICKS
	o.cooldown_ticks = SimConstants.ACTION_COOLDOWN_TICKS
	journal.append({
		"t": tick,
		"ev": &"action",
		"op": o.id,
		"kind": int(cmd.action_kind),
		"tx": cmd.target_cell.x,
		"ty": cmd.target_cell.y,
		"fuse": fuse,
	})
	if cmd.action_kind == AgentCommand.ActionKind.BREACH_CHARGE:
		pending.append({
			"due": tick + fuse,
			"cx": cmd.target_cell.x,
			"cy": cmd.target_cell.y,
			"op": o.id,
		})
	o.queue.advance_cursor()
