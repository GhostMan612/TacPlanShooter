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


static func compile_commands(m: GreyboxMap, start: Vector2i, cells: Array[Vector2i], waits: Dictionary = {}, orders: Dictionary = {}) -> Array[AgentCommand]:
	var commands: Array[AgentCommand] = []
	var door_actions := {}
	var pending_waits := waits.duplicate()
	var pending_orders := orders.duplicate(true)
	_append_node(m, commands, pending_waits, pending_orders, start, cells, -1)
	for i in range(cells.size()):
		var cell := cells[i]
		if m.door_cells.has(cell) and m.is_solid(cell) and not door_actions.has(cell):
			var action := AgentCommand.new()
			action.command_type = AgentCommand.CommandType.PERFORM_ACTION
			action.target_cell = cell
			action.action_kind = AgentCommand.ActionKind.BREACH_CHARGE
			commands.append(action)
			door_actions[cell] = true
		commands.append(move_cmd(cell))
		_append_node(m, commands, pending_waits, pending_orders, cell, cells, i)
	return commands


static func _append_node(m: GreyboxMap, commands: Array[AgentCommand], waits: Dictionary, orders: Dictionary, cell: Vector2i, cells: Array[Vector2i], index: int) -> void:
	var order: Dictionary = orders.get(cell, {})
	orders.erase(cell)
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
	_append_wait(commands, waits, cell)
	if order.has("action") and int(order["action"]) != int(AgentCommand.ActionKind.NONE):
		var throw := AgentCommand.new()
		throw.command_type = AgentCommand.CommandType.PERFORM_ACTION
		throw.action_kind = order["action"]
		throw.target_cell = action_target(m, cell, cells, index)
		commands.append(throw)


static func action_target(m: GreyboxMap, cell: Vector2i, cells: Array[Vector2i], index: int) -> Vector2i:
	var best := cell
	var last := mini(index + ACTION_LOOKAHEAD_CELLS, cells.size() - 1)
	for j in range(index + 1, last + 1):
		var c := cells[j]
		if m.in_bounds(c) and not m.is_solid(c):
			best = c
	return best


static func _append_wait(commands: Array[AgentCommand], waits: Dictionary, cell: Vector2i) -> void:
	if not waits.has(cell):
		return
	var command := AgentCommand.new()
	command.command_type = AgentCommand.CommandType.WAIT_GO_CODE
	command.go_code = waits[cell]
	commands.append(command)
	waits.erase(cell)


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


static func move_cmd(c: Vector2i) -> AgentCommand:
	var cmd := AgentCommand.new()
	cmd.command_type = AgentCommand.CommandType.MOVE_TO_CELL
	cmd.target_cell = c
	return cmd
