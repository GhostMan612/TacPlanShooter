# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name RoutePlanner
extends RefCounted


const NO_CELL := Vector2i(-1, -1)


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
	var commands: Array[AgentCommand] = []
	for c in cells:
		commands.append(move_cmd(c))
	return {"cells": cells, "commands": commands, "blocked_at": blocked}


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
