# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name SquadTactics
extends RefCounted

enum Doctrine { RECRUIT, VETERAN, TIER_ONE }

const CALLOUT_COOLDOWN_TICKS := 90
const MAX_FEED := 16

const DOCTRINES := {
	Doctrine.RECRUIT: {
		"reaction_mult": 1.35,
		"max_goap_depth": 2,
		"allow_grenades": false,
		"allow_smoke": false,
		"bound_cadence": 24,
		"anti_drone_delay": 18,
	},
	Doctrine.VETERAN: {
		"reaction_mult": 1.0,
		"max_goap_depth": 4,
		"allow_grenades": true,
		"allow_smoke": true,
		"bound_cadence": 12,
		"anti_drone_delay": 6,
	},
	Doctrine.TIER_ONE: {
		"reaction_mult": 0.8,
		"max_goap_depth": 4,
		"allow_grenades": true,
		"allow_smoke": true,
		"bound_cadence": 6,
		"anti_drone_delay": 0,
	},
}

var callout_cooldowns: Dictionary = {}
var feed: Array[Dictionary] = []
var bound_epoch: int = 0
var suppressor_id: int = -1
var flanker_id: int = -1
var flank_target_cell: Vector2i = Vector2i(-1, -1)
var flank_search_cooldown: int = 0


static func doctrine_config(d: int) -> Dictionary:
	return DOCTRINES.get(d, DOCTRINES[Doctrine.VETERAN])


static func scaled_reaction_ticks(base_ticks: int, d: int) -> int:
	var cfg: Dictionary = doctrine_config(d)
	return maxi(1, int(round(float(base_ticks) * float(cfg.get("reaction_mult", 1.0)))))


func tick_down() -> void:
	if flank_search_cooldown > 0:
		flank_search_cooldown -= 1
	var keys: Array = callout_cooldowns.keys()
	for k in keys:
		var left: int = int(callout_cooldowns[k]) - 1
		if left <= 0:
			callout_cooldowns.erase(k)
		else:
			callout_cooldowns[k] = left


func emit_callout(journal: Array[Dictionary], tick: int, op_id: int, callout: String, cell: Vector2i = Vector2i(-1, -1)) -> bool:
	var key: String = "%d:%s" % [op_id, callout]
	if callout_cooldowns.has(key):
		return false
	callout_cooldowns[key] = CALLOUT_COOLDOWN_TICKS
	var entry: Dictionary = {
		"t": tick,
		"ev": &"ai_callout",
		"op": op_id,
		"callout": callout,
		"cx": cell.x,
		"cy": cell.y,
	}
	journal.append(entry)
	feed.append(entry)
	if feed.size() > MAX_FEED:
		feed.remove_at(0)
	return true


static func blocks_lof(shooter_cell: Vector2i, target_cell: Vector2i, ally_cell: Vector2i) -> bool:
	if ally_cell == shooter_cell or ally_cell == target_cell:
		return true
	var a := Vector2(float(shooter_cell.x) + 0.5, float(shooter_cell.y) + 0.5)
	var b := Vector2(float(target_cell.x) + 0.5, float(target_cell.y) + 0.5)
	var p := Vector2(float(ally_cell.x) + 0.5, float(ally_cell.y) + 0.5)
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(p, a, b)
	return closest.distance_to(p) < 0.48


static func assign_crossfire_cells(map: GreyboxMap, funnel_cell: Vector2i, approach_dir: Vector2i, count: int, claimed: Dictionary, segs: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if map == null or count <= 0:
		return out
	var funnel_center := Vector2(float(funnel_cell.x) + 0.5, float(funnel_cell.y) + 0.5)
	var fwd := Vector2(float(approach_dir.x), float(approach_dir.y))
	if fwd.length_squared() < 0.01:
		fwd = Vector2.RIGHT
	else:
		fwd = fwd.normalized()
	var left_v := Vector2(-fwd.y, fwd.x)
	var left_cands: Array[Dictionary] = []
	var right_cands: Array[Dictionary] = []
	var min_x: int = maxi(1, funnel_cell.x - 6)
	var max_x: int = mini(map.width_cells - 2, funnel_cell.x + 6)
	var min_y: int = maxi(1, funnel_cell.y - 6)
	var max_y: int = mini(map.height_cells - 2, funnel_cell.y + 6)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var c := Vector2i(x, y)
			if c == funnel_cell or claimed.has(c):
				continue
			if map.is_solid(c) or map.door_cells.has(c):
				continue
			var d_cells: int = absi(c.x - funnel_cell.x) + absi(c.y - funnel_cell.y)
			if d_cells < 2 or d_cells > 7:
				continue
			var cc := Vector2(float(c.x) + 0.5, float(c.y) + 0.5)
			if not _line_clear(cc, funnel_center, segs):
				continue
			var rel: Vector2 = (cc - funnel_center).normalized()
			var lat: float = rel.dot(left_v)
			var fwd_dot: float = rel.dot(fwd)
			var wall_adj: int = 0
			for d in InfluenceMap.ORTHO:
				if map.is_solid(c + d):
					wall_adj += 1
			var score: int = wall_adj * 12 - absi(d_cells - 3) * 6 + (15 if fwd_dot >= -0.1 else 0)
			var bearing: int = int(round(rad_to_deg((funnel_center - cc).angle())))
			var item: Dictionary = {"cell": c, "bearing_deg": bearing, "score": score, "side": 1 if lat >= 0.0 else -1}
			if lat >= 0.0:
				left_cands.append(item)
			else:
				right_cands.append(item)
	left_cands.sort_custom(Callable(SquadTactics, "_cand_better"))
	right_cands.sort_custom(Callable(SquadTactics, "_cand_better"))
	var chosen_cells: Array[Vector2i] = []
	var side_turn: int = 0
	while out.size() < count and (not left_cands.is_empty() or not right_cands.is_empty()):
		var pick_left: bool = (side_turn % 2 == 0 and not left_cands.is_empty()) or right_cands.is_empty()
		var pool: Array[Dictionary] = left_cands if pick_left else right_cands
		side_turn += 1
		var picked := false
		while not pool.is_empty():
			var cand: Dictionary = pool[0]
			pool.remove_at(0)
			var cell: Vector2i = cand["cell"]
			if claimed.has(cell):
				continue
			var conflict := false
			for prev in chosen_cells:
				if blocks_lof(prev, funnel_cell, cell) or blocks_lof(cell, funnel_cell, prev):
					conflict = true
					break
				if absi(prev.x - cell.x) + absi(prev.y - cell.y) < 2:
					conflict = true
					break
			if conflict:
				continue
			claimed[cell] = true
			chosen_cells.append(cell)
			out.append(cand)
			picked = true
			break
		if not picked and left_cands.is_empty() and right_cands.is_empty():
			break
	return out


func assign_bounding_roles(map: GreyboxMap, actors_by_id: Dictionary, brains_by_id: Dictionary, squad: SquadCoordinator, lkp_pos: Vector2, influence: InfluenceMap, segs: Array) -> Dictionary:
	var alive_ids: Array = []
	for id in actors_by_id.keys():
		var actor: SimOperative = actors_by_id[id]
		if actor == null or not actor.is_alive():
			continue
		if not brains_by_id.has(id):
			continue
		var brain: EnemyAi = brains_by_id[id]
		if brain.is_stunned() or brain.state == int(EnemyAi.State.SURRENDER):
			continue
		alive_ids.append(int(id))
	alive_ids.sort()
	if alive_ids.size() < 2:
		suppressor_id = -1
		flanker_id = -1
		return {}
	if suppressor_id >= 0 and flanker_id >= 0 and alive_ids.has(suppressor_id) and alive_ids.has(flanker_id) and flank_target_cell != Vector2i(-1, -1):
		var cur_flanker: SimOperative = actors_by_id[flanker_id]
		if GridUtil.cell_of(cur_flanker.pos) == flank_target_cell:
			var old_sup: int = suppressor_id
			suppressor_id = flanker_id
			flanker_id = old_sup
			bound_epoch += 1
			flank_target_cell = Vector2i(-1, -1)
	if not alive_ids.has(suppressor_id) or not alive_ids.has(flanker_id) or suppressor_id == flanker_id:
		var best_sup: int = -1
		var best_sup_score: int = -999999
		for id in alive_ids:
			var brain: EnemyAi = brains_by_id[id]
			var actor: SimOperative = actors_by_id[id]
			var sc: int = 0
			if brain.archetype == &"heavy_gunner":
				sc += 40
			elif brain.archetype == &"room_anchor":
				sc += 25
			elif brain.archetype == &"tactical_flanker":
				sc -= 15
			var acell: Vector2i = GridUtil.cell_of(actor.pos)
			if influence.is_hard_cover_from(map, acell, lkp_pos, segs):
				sc += 15
			if sc > best_sup_score or (sc == best_sup_score and (best_sup < 0 or id < best_sup)):
				best_sup_score = sc
				best_sup = id
		var best_flank: int = -1
		var best_flank_score: int = -999999
		for id in alive_ids:
			if id == best_sup:
				continue
			var brain: EnemyAi = brains_by_id[id]
			var sc: int = 0
			if brain.archetype == &"tactical_flanker":
				sc += 40
			elif brain.archetype == &"patrol_sentry":
				sc += 15
			if sc > best_flank_score or (sc == best_flank_score and (best_flank < 0 or id < best_flank)):
				best_flank_score = sc
				best_flank = id
		suppressor_id = best_sup
		flanker_id = best_flank
	if suppressor_id >= 0:
		squad.assign_role(suppressor_id, int(SquadCoordinator.Role.SUPPRESSOR))
	if flanker_id >= 0:
		squad.assign_role(flanker_id, int(SquadCoordinator.Role.FLANKER))
	if flank_target_cell == Vector2i(-1, -1) and flanker_id >= 0 and flank_search_cooldown <= 0:
		var flanker_op: SimOperative = actors_by_id[flanker_id]
		flank_target_cell = pick_flank_goal(map, GridUtil.cell_of(flanker_op.pos), lkp_pos, influence, segs)
		if flank_target_cell == Vector2i(-1, -1):
			flank_search_cooldown = 12
	return {
		"suppressor_id": suppressor_id,
		"flanker_id": flanker_id,
		"flank_cell": flank_target_cell,
		"epoch": bound_epoch,
	}


static func pick_flank_goal(map: GreyboxMap, origin_cell: Vector2i, lkp_pos: Vector2, influence: InfluenceMap, segs: Array) -> Vector2i:
	var lkp_cell := Vector2i(int(floor(lkp_pos.x)), int(floor(lkp_pos.y)))
	var raw_cands: Array[Dictionary] = []
	for y in range(1, map.height_cells - 1):
		for x in range(1, map.width_cells - 1):
			var c := Vector2i(x, y)
			if c == origin_cell or map.is_solid(c) or map.door_cells.has(c):
				continue
			var cc := Vector2(float(x) + 0.5, float(y) + 0.5)
			var dist_lkp: float = cc.distance_to(lkp_pos)
			if dist_lkp < 2.0 or dist_lkp > 7.5:
				continue
			if not _line_clear(cc, lkp_pos, segs):
				continue
			var manh: int = absi(c.x - origin_cell.x) + absi(c.y - origin_cell.y)
			var approx: int = 200 + absi(c.y - lkp_cell.y) * 12 - manh * 6 - influence.effective_danger(c)
			raw_cands.append({"cell": c, "score": approx})
	raw_cands.sort_custom(Callable(SquadTactics, "_cand_better"))
	var limit: int = mini(raw_cands.size(), 16)
	var best_cell := Vector2i(-1, -1)
	var best_score: int = -999999
	for i in range(limit):
		var c: Vector2i = raw_cands[i]["cell"]
		var path: Array[Vector2i] = influence.find_tactical_path(map, origin_cell, c, 2)
		if path.is_empty():
			continue
		var path_danger: int = 0
		for pc in path:
			path_danger += influence.effective_danger(pc)
		var lat_bonus: int = absi(c.y - lkp_cell.y) * 12
		var score: int = 200 + lat_bonus - path_danger - path.size() * 6
		if score > best_score:
			best_score = score
			best_cell = c
	return best_cell


func to_dict() -> Dictionary:
	var cd_rows: Array = []
	var keys: Array = callout_cooldowns.keys()
	keys.sort()
	for k in keys:
		cd_rows.append([String(k), int(callout_cooldowns[k])])
	var feed_rows: Array = []
	for f in feed:
		feed_rows.append({
			"t": int(f.get("t", 0)),
			"ev": String(f.get("ev", "ai_callout")),
			"op": int(f.get("op", -1)),
			"callout": String(f.get("callout", "")),
			"cx": int(f.get("cx", -1)),
			"cy": int(f.get("cy", -1)),
		})
	return {
		"cooldowns": cd_rows,
		"feed": feed_rows,
		"epoch": bound_epoch,
		"sup_id": suppressor_id,
		"flank_id": flanker_id,
		"fcx": flank_target_cell.x,
		"fcy": flank_target_cell.y,
		"fcd": flank_search_cooldown,
	}


static func from_dict(d: Dictionary) -> SquadTactics:
	var t := SquadTactics.new()
	for row in d.get("cooldowns", []):
		t.callout_cooldowns[String(row[0])] = int(row[1])
	for f in d.get("feed", []):
		t.feed.append({
			"t": int(f.get("t", 0)),
			"ev": StringName(String(f.get("ev", "ai_callout"))),
			"op": int(f.get("op", -1)),
			"callout": String(f.get("callout", "")),
			"cx": int(f.get("cx", -1)),
			"cy": int(f.get("cy", -1)),
		})
	t.bound_epoch = int(d.get("epoch", 0))
	t.suppressor_id = int(d.get("sup_id", -1))
	t.flanker_id = int(d.get("flank_id", -1))
	t.flank_target_cell = Vector2i(int(d.get("fcx", -1)), int(d.get("fcy", -1)))
	t.flank_search_cooldown = int(d.get("fcd", 0))
	return t


static func _cand_better(a: Dictionary, b: Dictionary) -> bool:
	var sa: int = int(a["score"])
	var sb: int = int(b["score"])
	if sa != sb:
		return sa > sb
	var ca: Vector2i = a["cell"]
	var cb: Vector2i = b["cell"]
	return ca.y < cb.y or (ca.y == cb.y and ca.x < cb.x)


static func _line_clear(a: Vector2, b: Vector2, segs: Array) -> bool:
	var d := b - a
	for s in segs:
		var t: float = Visibility._ray_hit_t(a, d, s[0], s[1])
		if t > 0.000001 and t < 0.999999:
			return false
	return true
