# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name InfluenceMap
extends RefCounted

const ORTHO: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const NO_CELL := Vector2i(-1, -1)
const MAX_DANGER := 200
const SMOKE_DANGER_PERCENT := 30

var width: int = 16
var height: int = 12
var danger: PackedInt32Array = PackedInt32Array()
var cover: PackedInt32Array = PackedInt32Array()
var smoke: PackedInt32Array = PackedInt32Array()
var smoke_zones: Array[Dictionary] = []
var _cone_cache: Dictionary = {}
var _cone_sig: int = -1


func setup(w: int, h: int) -> void:
	width = maxi(w, 1)
	height = maxi(h, 1)
	var count: int = width * height
	danger.resize(count)
	cover.resize(count)
	smoke.resize(count)
	danger.fill(0)
	cover.fill(0)
	smoke.fill(0)


func ensure_size(map: GreyboxMap) -> void:
	if map == null:
		return
	if width != map.width_cells or height != map.height_cells or danger.size() != map.width_cells * map.height_cells:
		setup(map.width_cells, map.height_cells)


func _idx(cell: Vector2i) -> int:
	return cell.y * width + cell.x


func _in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func clear_dynamic(current_tick: int) -> void:
	danger.fill(0)
	smoke.fill(0)
	var keep: Array[Dictionary] = []
	for z in smoke_zones:
		var until_tick: int = int(z.get("until_tick", 0))
		if until_tick <= current_tick:
			continue
		keep.append(z)
		var cx: int = int(z.get("cx", 0))
		var cy: int = int(z.get("cy", 0))
		var rad: int = int(z.get("radius", 1))
		var r2: int = rad * rad
		for y in range(maxi(0, cy - rad), mini(height, cy + rad + 1)):
			for x in range(maxi(0, cx - rad), mini(width, cx + rad + 1)):
				var dx: int = x - cx
				var dy: int = y - cy
				if dx * dx + dy * dy <= r2:
					smoke[y * width + x] = 1
	smoke_zones = keep


func add_smoke_zone(cell: Vector2i, radius_cells: int, until_tick: int) -> void:
	smoke_zones.append({
		"cx": cell.x,
		"cy": cell.y,
		"radius": maxi(radius_cells, 1),
		"until_tick": until_tick,
	})
	var r2: int = radius_cells * radius_cells
	for y in range(maxi(0, cell.y - radius_cells), mini(height, cell.y + radius_cells + 1)):
		for x in range(maxi(0, cell.x - radius_cells), mini(width, cell.x + radius_cells + 1)):
			var dx: int = x - cell.x
			var dy: int = y - cell.y
			if dx * dx + dy * dy <= r2:
				var idx: int = y * width + x
				if idx >= 0 and idx < smoke.size():
					smoke[idx] = 1


func is_smoked(cell: Vector2i) -> bool:
	if not _in_grid(cell):
		return false
	var idx: int = _idx(cell)
	if idx < 0 or idx >= smoke.size():
		return false
	return smoke[idx] > 0


func raw_danger(cell: Vector2i) -> int:
	if not _in_grid(cell):
		return MAX_DANGER
	var idx: int = _idx(cell)
	if idx < 0 or idx >= danger.size():
		return MAX_DANGER
	return danger[idx]


func effective_danger(cell: Vector2i) -> int:
	var raw: int = raw_danger(cell)
	if is_smoked(cell):
		return int(raw * SMOKE_DANGER_PERCENT / 100)
	return raw


func add_cell_danger(cell: Vector2i, penalty: int) -> void:
	if not _in_grid(cell):
		return
	var idx: int = _idx(cell)
	if idx >= 0 and idx < danger.size():
		danger[idx] = clampi(danger[idx] + penalty, 0, MAX_DANGER)


func _map_signature(map: GreyboxMap) -> int:
	var h: int = map.width_cells * 131 + map.height_cells * 17 + map.solid_cells.size() * 31
	for dc in GreyboxMap.sorted_cells(map.door_open):
		h = (h * 33 + dc.x * 7 + dc.y * 13 + (1 if bool(map.door_open.get(dc, false)) else 0)) & 0x7FFFFFFF
	return h


func stamp_cone_danger(map: GreyboxMap, origin: Vector2, facing_deg: float, range_cells: float, half_angle_deg: float, penalty: int, segs: Array) -> void:
	ensure_size(map)
	var sig: int = _map_signature(map)
	if sig != _cone_sig:
		_cone_sig = sig
		_cone_cache.clear()
	var key := "%d:%d:%d:%d:%d" % [int(round(origin.x * 16.0)), int(round(origin.y * 16.0)), int(round(facing_deg * 4.0)), int(round(range_cells * 10.0)), int(round(half_angle_deg * 10.0))]
	var cells: Array[Vector2i] = []
	if _cone_cache.has(key):
		cells = _cone_cache[key]
	else:
		var min_x: int = maxi(0, int(floor(origin.x - range_cells)))
		var max_x: int = mini(map.width_cells - 1, int(ceil(origin.x + range_cells)))
		var min_y: int = maxi(0, int(floor(origin.y - range_cells)))
		var max_y: int = mini(map.height_cells - 1, int(ceil(origin.y + range_cells)))
		for y in range(min_y, max_y + 1):
			for x in range(min_x, max_x + 1):
				var c := Vector2i(x, y)
				if map.is_solid(c):
					continue
				var center := Vector2(float(x) + 0.5, float(y) + 0.5)
				var delta: Vector2 = center - origin
				var dist: float = delta.length()
				if dist > range_cells:
					continue
				if dist > 0.001:
					var ang_deg: float = rad_to_deg(delta.angle())
					if absf(_angle_diff(ang_deg, facing_deg)) > half_angle_deg:
						continue
					if not _line_clear(origin, center, segs):
						continue
				cells.append(c)
		_cone_cache[key] = cells
	for c in cells:
		if not is_smoked(c):
			add_cell_danger(c, penalty)


func stamp_lane_danger(map: GreyboxMap, from_pos: Vector2, to_pos: Vector2, penalty: int, segs: Array) -> void:
	ensure_size(map)
	var delta: Vector2 = to_pos - from_pos
	var dist: float = delta.length()
	if dist < 0.05:
		add_cell_danger(Vector2i(int(floor(from_pos.x)), int(floor(from_pos.y))), penalty)
		return
	var steps: int = int(ceil(dist * 4.0))
	var stamped := {}
	for i in range(steps + 1):
		var t: float = float(i) / float(maxi(steps, 1))
		var p: Vector2 = from_pos + delta * t
		var c := Vector2i(int(floor(p.x)), int(floor(p.y)))
		if not map.in_bounds(c) or map.is_solid(c):
			break
		if not _line_clear(from_pos, p, segs):
			break
		if not stamped.has(c):
			stamped[c] = true
			add_cell_danger(c, penalty)


func cover_score_at(map: GreyboxMap, cell: Vector2i, threat_pos: Vector2, segs: Array) -> int:
	if not map.in_bounds(cell) or map.is_solid(cell) or map.door_cells.has(cell):
		return 0
	var exits: int = 0
	var dir_wall_bonus: int = 0
	var peek_bonus: int = 0
	var center := Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5)
	var to_threat: Vector2 = (threat_pos - center)
	var to_threat_n: Vector2 = to_threat.normalized() if to_threat.length_squared() > 0.0001 else Vector2.RIGHT
	for d in ORTHO:
		var nb: Vector2i = cell + d
		if map.is_solid(nb):
			if Vector2(d).dot(to_threat_n) > 0.3:
				dir_wall_bonus = 30
		else:
			exits += 1
			if peek_bonus == 0 and _line_clear(Vector2(nb) + Vector2(0.5, 0.5), threat_pos, segs):
				peek_bonus = 25
	if exits == 0:
		return 0
	var score: int = dir_wall_bonus + peek_bonus
	if not _line_clear(center, threat_pos, segs):
		score += 50
	if exits >= 2:
		score += 15
	else:
		score -= 30
	return clampi(score, 0, 100)


func refresh_cover_scores(map: GreyboxMap, threat_pos: Vector2, segs: Array) -> void:
	ensure_size(map)
	for y in range(map.height_cells):
		for x in range(map.width_cells):
			var c := Vector2i(x, y)
			cover[y * width + x] = cover_score_at(map, c, threat_pos, segs)


func is_hard_cover_from(map: GreyboxMap, cell: Vector2i, threat_pos: Vector2, segs: Array) -> bool:
	if not map.in_bounds(cell) or map.is_solid(cell) or map.door_cells.has(cell):
		return false
	var has_wall := false
	var has_exit := false
	for d in ORTHO:
		var nb: Vector2i = cell + d
		if map.is_solid(nb):
			has_wall = true
		else:
			has_exit = true
	if not has_wall or not has_exit:
		return false
	var center := Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5)
	return not _line_clear(center, threat_pos, segs)


func best_cover_cell(map: GreyboxMap, origin_cell: Vector2i, threat_pos: Vector2, max_radius: int, claimed: Dictionary, require_hard_occlusion: bool, segs: Array) -> Vector2i:
	ensure_size(map)
	var best_cell := NO_CELL
	var best_score: int = -999999
	var min_x: int = maxi(0, origin_cell.x - max_radius)
	var max_x: int = mini(map.width_cells - 1, origin_cell.x + max_radius)
	var min_y: int = maxi(0, origin_cell.y - max_radius)
	var max_y: int = mini(map.height_cells - 1, origin_cell.y + max_radius)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var c := Vector2i(x, y)
			if claimed.has(c):
				continue
			if map.is_solid(c) or map.door_cells.has(c):
				continue
			if require_hard_occlusion and not is_hard_cover_from(map, c, threat_pos, segs):
				continue
			var cov: int = cover_score_at(map, c, threat_pos, segs)
			if cov <= 0:
				continue
			if GridPathfinder.find_path(map, origin_cell, c).is_empty():
				continue
			var manhattan: int = absi(c.x - origin_cell.x) + absi(c.y - origin_cell.y)
			var total: int = cov - effective_danger(c) - 4 * manhattan
			if total > best_score:
				best_score = total
				best_cell = c
	return best_cell


func best_peek_cell(map: GreyboxMap, cover_cell: Vector2i, threat_pos: Vector2, claimed: Dictionary, segs: Array) -> Vector2i:
	var best_cell := NO_CELL
	var best_score: int = -999999
	for d in ORTHO:
		var nb: Vector2i = cover_cell + d
		if not map.in_bounds(nb) or map.is_solid(nb) or map.door_cells.has(nb):
			continue
		if claimed.has(nb):
			continue
		var center := Vector2(float(nb.x) + 0.5, float(nb.y) + 0.5)
		if not _line_clear(center, threat_pos, segs):
			continue
		var score: int = 100 - effective_danger(nb)
		if score > best_score:
			best_score = score
			best_cell = nb
	return best_cell


func pick_grenade_landing_cell(map: GreyboxMap, thrower_pos: Vector2, target_cell: Vector2i, max_range: float, segs: Array) -> Vector2i:
	if map.in_bounds(target_cell) and not map.is_solid(target_cell):
		var tc := Vector2(float(target_cell.x) + 0.5, float(target_cell.y) + 0.5)
		if thrower_pos.distance_to(tc) <= max_range and _line_clear(thrower_pos, tc, segs):
			return target_cell
	var best_cell := NO_CELL
	var best_dist: float = 999999.0
	var blast_r: int = SimConstants.FRAG_RADIUS_CELLS
	var target_center := Vector2(float(target_cell.x) + 0.5, float(target_cell.y) + 0.5)
	for dy in range(-blast_r, blast_r + 1):
		for dx in range(-blast_r, blast_r + 1):
			var c := Vector2i(target_cell.x + dx, target_cell.y + dy)
			if not map.in_bounds(c) or map.is_solid(c):
				continue
			var cc := Vector2(float(c.x) + 0.5, float(c.y) + 0.5)
			if cc.distance_to(target_center) > float(blast_r):
				continue
			if thrower_pos.distance_to(cc) > max_range:
				continue
			if not _line_clear(thrower_pos, cc, segs):
				continue
			if not _line_clear(cc, target_center, segs):
				continue
			var score: float = cc.distance_to(target_center) * 10.0 + thrower_pos.distance_to(cc)
			if score < best_dist:
				best_dist = score
				best_cell = c
	return best_cell


func best_throw_cell(map: GreyboxMap, origin_cell: Vector2i, target_cell: Vector2i, max_throw_range: float, max_move_radius: int, claimed: Dictionary, segs: Array) -> Vector2i:
	ensure_size(map)
	var best_cell := NO_CELL
	var best_cost: int = 999999
	var target_center := Vector2(float(target_cell.x) + 0.5, float(target_cell.y) + 0.5)
	var reach_limit: float = max_throw_range + float(SimConstants.FRAG_RADIUS_CELLS)
	var min_x: int = maxi(0, origin_cell.x - max_move_radius)
	var max_x: int = mini(map.width_cells - 1, origin_cell.x + max_move_radius)
	var min_y: int = maxi(0, origin_cell.y - max_move_radius)
	var max_y: int = mini(map.height_cells - 1, origin_cell.y + max_move_radius)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var c := Vector2i(x, y)
			if claimed.has(c):
				continue
			if map.is_solid(c) or map.door_cells.has(c):
				continue
			var center := Vector2(float(c.x) + 0.5, float(c.y) + 0.5)
			if center.distance_to(target_center) > reach_limit:
				continue
			if pick_grenade_landing_cell(map, center, target_cell, max_throw_range, segs) == NO_CELL:
				continue
			var path: Array[Vector2i] = GridPathfinder.find_path(map, origin_cell, c)
			if path.is_empty():
				continue
			var cost: int = effective_danger(c) + 4 * path.size()
			if cost < best_cost:
				best_cost = cost
				best_cell = c
	return best_cell


func find_tactical_path(map: GreyboxMap, start: Vector2i, goal: Vector2i, danger_weight: int = 1, blocked_cells: Dictionary = {}) -> Array[Vector2i]:
	ensure_size(map)
	if not map.in_bounds(start) or not map.in_bounds(goal) or _is_wall(map, start) or _is_wall(map, goal):
		var empty: Array[Vector2i] = []
		return empty
	if start == goal:
		var single: Array[Vector2i] = [start]
		return single
	var g: Dictionary = {start: 0}
	var closed: Dictionary = {}
	var parent: Dictionary = {}
	var open_set: Array = [[_h(start, goal), 0, start]]
	while open_set.size() > 0:
		var best: int = 0
		for i in range(1, open_set.size()):
			var fi: int = int(open_set[i][0])
			var fb: int = int(open_set[best][0])
			if fi < fb or (fi == fb and _less(open_set[i][2], open_set[best][2])):
				best = i
		var cell: Vector2i = open_set[best][2]
		open_set.remove_at(best)
		if cell == goal:
			return _reconstruct(parent, goal)
		if closed.has(cell):
			continue
		closed[cell] = true
		for d in ORTHO:
			var nb: Vector2i = cell + d
			if not map.in_bounds(nb) or _is_wall(map, nb) or closed.has(nb):
				continue
			if blocked_cells.has(nb) and nb != start:
				continue
			var step_cost: int = 10 + effective_danger(nb) * maxi(danger_weight, 0)
			var ng: int = int(g[cell]) + step_cost
			if g.has(nb) and int(g[nb]) <= ng:
				continue
			g[nb] = ng
			parent[nb] = cell
			open_set.push_back([ng + _h(nb, goal), ng, nb])
	var none: Array[Vector2i] = []
	return none


func to_dict() -> Dictionary:
	var d_arr: Array = []
	for v in danger:
		d_arr.append(int(v))
	var c_arr: Array = []
	for v in cover:
		c_arr.append(int(v))
	var s_arr: Array = []
	for v in smoke:
		s_arr.append(int(v))
	var zones: Array = []
	for z in smoke_zones:
		zones.append({
			"cx": int(z.get("cx", 0)),
			"cy": int(z.get("cy", 0)),
			"radius": int(z.get("radius", 1)),
			"until_tick": int(z.get("until_tick", 0)),
		})
	return {
		"w": width,
		"h": height,
		"danger": d_arr,
		"cover": c_arr,
		"smoke": s_arr,
		"smoke_zones": zones,
	}


static func from_dict(d: Dictionary) -> InfluenceMap:
	var m := InfluenceMap.new()
	m.setup(int(d.get("w", 16)), int(d.get("h", 12)))
	var d_arr: Array = d.get("danger", [])
	for i in range(mini(d_arr.size(), m.danger.size())):
		m.danger[i] = int(d_arr[i])
	var c_arr: Array = d.get("cover", [])
	for i in range(mini(c_arr.size(), m.cover.size())):
		m.cover[i] = int(c_arr[i])
	var s_arr: Array = d.get("smoke", [])
	for i in range(mini(s_arr.size(), m.smoke.size())):
		m.smoke[i] = int(s_arr[i])
	for z in d.get("smoke_zones", []):
		m.smoke_zones.append({
			"cx": int(z.get("cx", 0)),
			"cy": int(z.get("cy", 0)),
			"radius": int(z.get("radius", 1)),
			"until_tick": int(z.get("until_tick", 0)),
		})
	return m


static func _is_wall(map: GreyboxMap, cell: Vector2i) -> bool:
	return map.is_solid(cell) and not map.door_cells.has(cell)


static func _h(a: Vector2i, b: Vector2i) -> int:
	return 10 * (absi(a.x - b.x) + absi(a.y - b.y))


static func _less(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)


static func _reconstruct(parent: Dictionary, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [goal]
	var c := goal
	while parent.has(c):
		c = parent[c]
		path.push_front(c)
	return path


static func _line_clear(a: Vector2, b: Vector2, segs: Array) -> bool:
	var d := b - a
	for s in segs:
		var t: float = Visibility._ray_hit_t(a, d, s[0], s[1])
		if t > 0.000001 and t < 0.999999:
			return false
	return true


static func _angle_diff(a: float, b: float) -> float:
	return fposmod(a - b + 180.0, 360.0) - 180.0
