# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name RoutePlanner
extends RefCounted


const NO_CELL := Vector2i(-1, -1)
const ACTION_LOOKAHEAD_CELLS := 3


static func walkable(m: GreyboxMap, c: Vector2i) -> bool:
	if not m.in_bounds(c):
		return false
	return m.door_cells.has(c) or not m.solid_cells.has(c)


static func repair_freehand_waypoints(m: GreyboxMap, waypoints: Array[Vector2i]) -> Array[Vector2i]:
	if m == null:
		return waypoints.duplicate()
	var cleaned: Array[Vector2i] = []
	for wp in waypoints:
		if cleaned.is_empty() or cleaned[cleaned.size() - 1] != wp:
			cleaned.append(wp)
	var out: Array[Vector2i] = []
	for idx in range(cleaned.size()):
		var wp: Vector2i = cleaned[idx]
		if walkable(m, wp):
			out.append(wp)
		elif idx == cleaned.size() - 1 and cleaned.size() >= 3:
			for d in GridPathfinder.ORTHO:
				var nb: Vector2i = wp + d
				if walkable(m, nb):
					out.append(nb)
					break
	return out


static func plan(m: GreyboxMap, start: Vector2i, waypoints: Array[Vector2i]) -> Dictionary:
	var cells: Array[Vector2i] = []
	var blocked := NO_CELL
	var prev := start
	for c in waypoints:
		if c == prev or (not cells.is_empty() and c == cells[cells.size() - 1]):
			continue
		var step_cells := _connect(m, prev, c)
		if step_cells.is_empty():
			blocked = c
			break
		for sc in step_cells:
			cells.append(sc)
		prev = c
	return {"cells": cells, "commands": compile_commands(m, start, cells), "blocked_at": blocked}


static func compile_commands(m: GreyboxMap, start: Vector2i, cells: Array[Vector2i], waits: Dictionary = {}, orders: Dictionary = {}, floor_idx: int = 0) -> Array[AgentCommand]:
	var commands: Array[AgentCommand] = []
	var door_actions := {}
	var pending_waits := waits.duplicate()
	var pending_orders := orders.duplicate(true)
	_append_node(m, commands, pending_waits, pending_orders, start, cells, -1, floor_idx)
	for i in range(cells.size()):
		var cell := cells[i]
		if m.door_cells.has(cell) and m.is_solid(cell) and not door_actions.has(cell):
			var action := AgentCommand.new()
			action.command_type = AgentCommand.CommandType.PERFORM_ACTION
			action.target_cell = cell
			action.target_floor = floor_idx
			action.action_kind = AgentCommand.ActionKind.BREACH_CHARGE
			commands.append(action)
			door_actions[cell] = true
		commands.append(move_cmd(cell, floor_idx))
		_append_node(m, commands, pending_waits, pending_orders, cell, cells, i, floor_idx)
	return commands


static func compile_multi_floor(floor_maps: Array[GreyboxMap], segments: Array, waits: Dictionary = {}, orders: Dictionary = {}) -> Array[AgentCommand]:
	var out: Array[AgentCommand] = []
	for seg in segments:
		var fl := int(seg.get("floor", 0))
		var fmap := floor_maps[fl] if fl >= 0 and fl < floor_maps.size() else floor_maps[0]
		var seg_start: Vector2i = seg.get("start", Vector2i.ZERO)
		var seg_cells: Array[Vector2i] = []
		for c in seg.get("cells", []):
			seg_cells.append(c as Vector2i)
		for cmd in compile_commands(fmap, seg_start, seg_cells, waits, orders, fl):
			out.append(cmd)
		var next_fl := int(seg.get("stair_to_floor", -1))
		if next_fl >= 0:
			var stair := AgentCommand.new()
			stair.command_type = AgentCommand.CommandType.USE_STAIRS
			stair.target_floor = next_fl
			stair.target_cell = seg.get("stair_to_cell", Vector2i.ZERO)
			out.append(stair)
	return out


static func _node_entry(dict: Dictionary, cell: Vector2i, floor_idx: int, consume: bool) -> Variant:
	var k3 := Vector3i(cell.x, cell.y, floor_idx)
	if dict.has(k3):
		var v: Variant = dict[k3]
		if consume:
			dict.erase(k3)
		return v
	if floor_idx == 0 and dict.has(cell):
		var v2: Variant = dict[cell]
		if consume:
			dict.erase(cell)
		return v2
	return null


static func _append_node(m: GreyboxMap, commands: Array[AgentCommand], waits: Dictionary, orders: Dictionary, cell: Vector2i, cells: Array[Vector2i], index: int, floor_idx: int = 0) -> void:
	var raw_order: Variant = _node_entry(orders, cell, floor_idx, true)
	var order: Dictionary = raw_order if raw_order is Dictionary else {}
	if order.has("stance"):
		var stance := AgentCommand.new()
		stance.command_type = AgentCommand.CommandType.SET_STANCE
		stance.stance_name = StringName(order["stance"])
		commands.append(stance)
	if order.has("mode"):
		var mode := AgentCommand.new()
		mode.command_type = AgentCommand.CommandType.SET_MODE
		mode.mode_name = StringName(order["mode"])
		commands.append(mode)
	if order.has("fof"):
		var fof := AgentCommand.new()
		fof.command_type = AgentCommand.CommandType.SET_FIELD_OF_FIRE
		fof.bearing_deg = int(order["fof"])
		commands.append(fof)
	_append_wait(commands, waits, cell, floor_idx)
	if order.has("action") and int(order["action"]) != int(AgentCommand.ActionKind.NONE):
		var throw := AgentCommand.new()
		throw.command_type = AgentCommand.CommandType.PERFORM_ACTION
		throw.action_kind = order["action"]
		throw.target_cell = action_target(m, cell, cells, index)
		throw.target_floor = floor_idx
		commands.append(throw)


static func action_target(m: GreyboxMap, cell: Vector2i, cells: Array[Vector2i], index: int) -> Vector2i:
	var best := cell
	var last := mini(index + ACTION_LOOKAHEAD_CELLS, cells.size() - 1)
	for j in range(index + 1, last + 1):
		var c := cells[j]
		if m.in_bounds(c) and not m.is_solid(c):
			best = c
	return best


static func _append_wait(commands: Array[AgentCommand], waits: Dictionary, cell: Vector2i, floor_idx: int = 0) -> void:
	var w_val: Variant = _node_entry(waits, cell, floor_idx, true)
	if w_val == null:
		return
	var command := AgentCommand.new()
	command.command_type = AgentCommand.CommandType.WAIT_GO_CODE
	command.go_code = w_val
	commands.append(command)


static func _connect(m: GreyboxMap, a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not walkable(m, b):
		return out
	var d := b - a
	if absi(d.x) + absi(d.y) == 1:
		out.append(b)
		return out
	if absi(d.x) == 1 and absi(d.y) == 1:
		var horizontal := Vector2i(b.x, a.y)
		var vertical := Vector2i(a.x, b.y)
		if walkable(m, horizontal):
			out.append(horizontal)
		elif walkable(m, vertical):
			out.append(vertical)
		else:
			return out
		out.append(b)
		return out
	var path := GridPathfinder.find_path(m, a, b)
	if path.size() < 2:
		return out
	for i in range(1, path.size()):
		out.append(path[i])
	return out


static func path_points_px(start: Vector2i, cells: Array[Vector2i]) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(GridUtil.cell_center_px(start))
	for c in cells:
		pts.append(GridUtil.cell_center_px(c))
	return pts


static func move_cmd(c: Vector2i, floor_idx: int = 0) -> AgentCommand:
	var cmd := AgentCommand.new()
	cmd.command_type = AgentCommand.CommandType.MOVE_TO_CELL
	cmd.target_cell = c
	cmd.target_floor = floor_idx
	return cmd
