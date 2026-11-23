# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name GridPathfinder
extends RefCounted

const ORTHO: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func find_path(map: GreyboxMap, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var g: Dictionary = {}
	var closed: Dictionary = {}
	var parent: Dictionary = {}
	var open_set: Array = [[0, 0, start]]
	if not map.in_bounds(start) or not map.in_bounds(goal) or _is_wall(map, start) or _is_wall(map, goal):
		var empty: Array[Vector2i] = []
		return empty
	g[start] = 0
	while open_set.size() > 0:
		var best := 0
		for i in range(1, open_set.size()):
			if open_set[i][0] < open_set[best][0] or (open_set[i][0] == open_set[best][0] and _less(open_set[i][2], open_set[best][2])):
				best = i
		var cell: Vector2i = open_set[best][2]
		open_set.remove_at(best)
		if cell == goal:
			return _reconstruct(parent, goal)
		if closed.has(cell):
			continue
		closed[cell] = true
		for d in ORTHO:
			var nb := cell + d
			if not map.in_bounds(nb) or _is_wall(map, nb) or closed.has(nb):
				continue
			var ng := int(g[cell]) + 1
			if g.has(nb) and int(g[nb]) <= ng:
				continue
			g[nb] = ng
			parent[nb] = cell
			open_set.push_back([ng + _heuristic(nb, goal), ng, nb])
	var empty: Array[Vector2i] = []
	return empty


static func _is_wall(map: GreyboxMap, cell: Vector2i) -> bool:
	return map.is_solid(cell) and not map.door_cells.has(cell)


static func _less(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)


static func _heuristic(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


static func _reconstruct(parent: Dictionary, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [goal]
	var c := goal
	while parent.has(c):
		c = parent[c]
		path.push_front(c)
	return path
