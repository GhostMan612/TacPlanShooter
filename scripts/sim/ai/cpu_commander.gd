# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name CpuCommander
extends RefCounted

const ORTHO: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const CPU_ID_BASE := 100

var enabled: bool = false
var faction_id: int = 1
var doctrine: int = int(SquadTactics.Doctrine.VETERAN)
var mode: StringName = &"DEFEND"
var cpu_go_codes_issued: Dictionary = {}
var active_jammers: Array[Vector2i] = []
var barricaded_doors: Array[Vector2i] = []
var reserve_ids: Array[int] = []
var last_journal_idx: int = 0
var primary_focal_cell: Vector2i = Vector2i(-1, -1)


static func analyze_topology(map: GreyboxMap) -> Dictionary:
	var fatal_funnels: Array[Vector2i] = []
	var breach_points: Array[Vector2i] = []
	var cover_corners: Array[Vector2i] = []
	var objective_sightlines: Array[Vector2i] = []
	var rooms: Array[Array] = []
	if map == null:
		return {
			"fatal_funnels": fatal_funnels,
			"rooms": rooms,
			"breach_points": breach_points,
			"cover_corners": cover_corners,
			"objective_sightlines": objective_sightlines,
		}
	var segs: Array = map.get_wall_segments()
	var funnel_set: Dictionary = {}
	for dc in GreyboxMap.sorted_cells(map.door_cells):
		funnel_set[dc] = true
		fatal_funnels.append(dc)
		if not bool(map.door_open.get(dc, false)):
			breach_points.append(dc)
	for y in range(1, map.height_cells - 1):
		for x in range(1, map.width_cells - 1):
			var c := Vector2i(x, y)
			if map.is_solid(c):
				var mat: StringName = map.wall_materials.get(c, &"")
				if mat == &"DRY_WALL":
					var ew_gap: bool = not map.is_solid(c + Vector2i(1, 0)) and not map.is_solid(c + Vector2i(-1, 0))
					var ns_gap: bool = not map.is_solid(c + Vector2i(0, 1)) and not map.is_solid(c + Vector2i(0, -1))
					if ew_gap or ns_gap:
						breach_points.append(c)
				continue
			var n_sol: bool = map.is_solid(c + Vector2i(0, -1))
			var s_sol: bool = map.is_solid(c + Vector2i(0, 1))
			var e_sol: bool = map.is_solid(c + Vector2i(1, 0))
			var w_sol: bool = map.is_solid(c + Vector2i(-1, 0))
			if (n_sol and s_sol and not e_sol and not w_sol) or (e_sol and w_sol and not n_sol and not s_sol):
				if not funnel_set.has(c):
					funnel_set[c] = true
					fatal_funnels.append(c)
			var adj_walls: int = (1 if n_sol else 0) + (1 if s_sol else 0) + (1 if e_sol else 0) + (1 if w_sol else 0)
			if adj_walls == 1 or adj_walls == 2:
				cover_corners.append(c)
	var target_cells: Array[Vector2i] = []
	for obj in map.objectives:
		var oc: Vector2i = _cell_from_entry(obj)
		if map.in_bounds(oc):
			target_cells.append(oc)
	for hs in map.hostage_spawns:
		var hc: Vector2i = _cell_from_entry(hs)
		if map.in_bounds(hc):
			target_cells.append(hc)
	for ez in map.extraction_zones:
		for raw_c in ez.get("cells", []):
			var ec: Vector2i = _cell_from_entry(raw_c)
			if map.in_bounds(ec):
				target_cells.append(ec)
	for y in range(1, map.height_cells - 1):
		for x in range(1, map.width_cells - 1):
			var c := Vector2i(x, y)
			if map.is_solid(c):
				continue
			var cc := Vector2(float(x) + 0.5, float(y) + 0.5)
			for tc in target_cells:
				var t_center := Vector2(float(tc.x) + 0.5, float(tc.y) + 0.5)
				if _line_clear(cc, t_center, segs):
					objective_sightlines.append(c)
					break
	var seen_room: Dictionary = {}
	for y in range(1, map.height_cells - 1):
		for x in range(1, map.width_cells - 1):
			var start := Vector2i(x, y)
			if seen_room.has(start) or map.is_solid(start) or funnel_set.has(start):
				continue
			var comp: Array[Vector2i] = []
			var q: Array[Vector2i] = [start]
			seen_room[start] = true
			while not q.is_empty():
				var cur: Vector2i = q.pop_front()
				comp.append(cur)
				for d in ORTHO:
					var nb: Vector2i = cur + d
					if not map.in_bounds(nb) or seen_room.has(nb) or map.is_solid(nb) or funnel_set.has(nb):
						continue
					seen_room[nb] = true
					q.append(nb)
			rooms.append(comp)
	return {
		"fatal_funnels": fatal_funnels,
		"rooms": rooms,
		"breach_points": breach_points,
		"cover_corners": cover_corners,
		"objective_sightlines": objective_sightlines,
	}


func generate_preplan(world: Variant, p_mode: StringName = &"DEFEND", p_doctrine: int = int(SquadTactics.Doctrine.VETERAN), min_units: int = 3) -> Dictionary:
	enabled = true
	mode = p_mode
	doctrine = p_doctrine
	cpu_go_codes_issued.clear()
	active_jammers.clear()
	barricaded_doors.clear()
	reserve_ids.clear()
	last_journal_idx = world.journal.size()
	var map: GreyboxMap = world.map
	var topo: Dictionary = analyze_topology(map)
	var segs: Array = map.get_wall_segments()
	world.ai.influence.ensure_size(map)
	_ensure_cpu_roster(world, topo, min_units)
	for id in world.ai.enemies.keys():
		var brain: EnemyAi = world.ai.enemies[id]
		brain.configure(brain.archetype, doctrine)
	var funnels: Array = topo["fatal_funnels"]
	for dc in funnels:
		if map.door_cells.has(dc) and not bool(map.door_open.get(dc, false)):
			world.door_system.add_door(dc)
			world.door_system.set_lock(dc, 1)
			barricaded_doors.append(dc)
			break
	for jnode in map.jammer_nodes:
		var jc: Vector2i = _cell_from_entry(jnode)
		if map.in_bounds(jc) and not map.is_solid(jc):
			active_jammers.append(jc)
	if active_jammers.is_empty():
		var corners: Array = topo["cover_corners"]
		if not corners.is_empty():
			active_jammers.append(corners[corners.size() / 2])
	var focal: Vector2i = _pick_focal_cell(map, topo, segs)
	primary_focal_cell = focal
	var claimed: Dictionary = {}
	var crossfire: Array[Dictionary] = SquadTactics.assign_crossfire_cells(map, focal, Vector2i(1, 0), 2, claimed, segs)
	var enemy_ids: Array = world.enemy_actors.keys()
	enemy_ids.sort()
	var plans_by_id: Dictionary = {}
	var anchor_idx: int = 0
	for id in enemy_ids:
		var actor: SimOperative = world.enemy_actors[id]
		var start_cell: Vector2i = GridUtil.cell_of(actor.pos)
		var cmds: Array[AgentCommand] = []
		if anchor_idx < crossfire.size():
			var cf: Dictionary = crossfire[anchor_idx]
			var cf_cell: Vector2i = cf["cell"]
			var cf_bearing: int = int(cf["bearing_deg"])
			cmds.append(_cmd_stance(&"cautious"))
			var path: Array[Vector2i] = GridPathfinder.find_path(map, start_cell, cf_cell)
			for i in range(1, path.size()):
				cmds.append(_cmd_move(path[i]))
			cmds.append(_cmd_fof(cf_bearing))
			cmds.append(_cmd_wait(&"alpha"))
			var shift_cell: Vector2i = _pick_reserve_shift(map, cf_cell, focal, claimed)
			if shift_cell != Vector2i(-1, -1):
				var shift_path: Array[Vector2i] = GridPathfinder.find_path(map, cf_cell, shift_cell)
				for i in range(1, shift_path.size()):
					cmds.append(_cmd_move(shift_path[i]))
				cmds.append(_cmd_fof(int(round(rad_to_deg((Vector2(focal) - Vector2(shift_cell)).angle())))))
			anchor_idx += 1
		else:
			reserve_ids.append(int(id))
			var patrol_pts: Array[Vector2i] = _pick_patrol_loop(map, start_cell, topo)
			cmds.append(_cmd_stance(&"normal"))
			var cur_c: Vector2i = start_cell
			for pt in patrol_pts:
				var leg: Array[Vector2i] = GridPathfinder.find_path(map, cur_c, pt)
				for i in range(1, leg.size()):
					cmds.append(_cmd_move(leg[i]))
				cur_c = pt
			cmds.append(_cmd_wait(&"bravo"))
			var reinforce_path: Array[Vector2i] = GridPathfinder.find_path(map, cur_c, focal)
			if reinforce_path.size() >= 2:
				var stop_idx: int = maxi(1, reinforce_path.size() - 2)
				for i in range(1, stop_idx + 1):
					cmds.append(_cmd_move(reinforce_path[i]))
		actor.queue.reset(cmds)
		plans_by_id[id] = cmds
	return {
		"topology": topo,
		"plans": plans_by_id,
		"crossfire": crossfire,
		"jammers": active_jammers.duplicate(),
		"barricaded_doors": barricaded_doors.duplicate(),
		"go_codes": [&"alpha", &"bravo"],
		"focal_cell": focal,
	}


func step_commander(world: Variant) -> void:
	if not enabled:
		return
	var j_size: int = world.journal.size()
	var saw_breach := false
	var saw_casualty := false
	var breach_cell := primary_focal_cell
	for i in range(last_journal_idx, j_size):
		var ev: Dictionary = world.journal[i]
		var ev_name: StringName = StringName(String(ev.get("ev", "")))
		if ev_name == &"breach_opened":
			saw_breach = true
			breach_cell = Vector2i(int(ev.get("cx", breach_cell.x)), int(ev.get("cy", breach_cell.y)))
		elif ev_name == &"action" and int(ev.get("kind", 0)) == int(AgentCommand.ActionKind.BREACH_CHARGE):
			saw_breach = true
			breach_cell = Vector2i(int(ev.get("tx", breach_cell.x)), int(ev.get("ty", breach_cell.y)))
		elif ev_name == &"kia":
			var kia_op: int = int(ev.get("op", -1))
			if world.enemy_actors.has(kia_op):
				saw_casualty = true
	last_journal_idx = j_size
	if saw_breach or world.ai.blackboard.alert_level >= int(ThreatBlackboard.Alert.COMBAT):
		issue_cpu_go_code(world, &"alpha")
	var drone_spotted := false
	for id in world.ai.enemies.keys():
		var brain: EnemyAi = world.ai.enemies[id]
		if brain.spotted_by_drone_id >= 0:
			drone_spotted = true
			break
	if saw_casualty or drone_spotted:
		issue_cpu_go_code(world, &"alpha")
		issue_cpu_go_code(world, &"bravo")
	if saw_breach:
		for id in world.ai.enemies.keys():
			var brain: EnemyAi = world.ai.enemies[id]
			if brain.heard_breach_cell == Vector2i(-1, -1):
				brain.heard_breach_cell = breach_cell


func issue_cpu_go_code(world: Variant, code: StringName) -> void:
	if cpu_go_codes_issued.has(code):
		return
	cpu_go_codes_issued[code] = true
	world.journal.append({"t": world.tick, "ev": &"cpu_go_issued", "code": String(code)})


func has_go_code(code: StringName) -> bool:
	return cpu_go_codes_issued.has(code)


func is_jammer_near(cell: Vector2i, max_dist_cells: int = 5) -> bool:
	for j in active_jammers:
		if absi(j.x - cell.x) + absi(j.y - cell.y) <= max_dist_cells:
			return true
	return false


func to_dict() -> Dictionary:
	var codes: Array = []
	for k in cpu_go_codes_issued.keys():
		codes.append(String(k))
	codes.sort()
	var jams: Array = []
	for j in active_jammers:
		jams.append([j.x, j.y])
	var barrs: Array = []
	for b in barricaded_doors:
		barrs.append([b.x, b.y])
	return {
		"enabled": enabled,
		"faction_id": faction_id,
		"doctrine": doctrine,
		"mode": String(mode),
		"go_codes": codes,
		"jammers": jams,
		"barricades": barrs,
		"reserves": reserve_ids.duplicate(),
		"last_j": last_journal_idx,
		"fx": primary_focal_cell.x,
		"fy": primary_focal_cell.y,
	}


static func from_dict(d: Dictionary) -> CpuCommander:
	var c := CpuCommander.new()
	c.enabled = bool(d.get("enabled", false))
	c.faction_id = int(d.get("faction_id", 1))
	c.doctrine = int(d.get("doctrine", int(SquadTactics.Doctrine.VETERAN)))
	c.mode = StringName(String(d.get("mode", "DEFEND")))
	for g in d.get("go_codes", []):
		c.cpu_go_codes_issued[StringName(String(g))] = true
	for j in d.get("jammers", []):
		c.active_jammers.append(Vector2i(int(j[0]), int(j[1])))
	for b in d.get("barricades", []):
		c.barricaded_doors.append(Vector2i(int(b[0]), int(b[1])))
	for r in d.get("reserves", []):
		c.reserve_ids.append(int(r))
	c.last_journal_idx = int(d.get("last_j", 0))
	c.primary_focal_cell = Vector2i(int(d.get("fx", -1)), int(d.get("fy", -1)))
	return c


func _ensure_cpu_roster(world: Variant, topo: Dictionary, min_units: int) -> void:
	var map: GreyboxMap = world.map
	var occupied: Dictionary = {}
	for op in world.operatives:
		occupied[GridUtil.cell_of(op.pos)] = true
	for hs in map.hostage_spawns:
		occupied[_cell_from_entry(hs)] = true
	for id in world.enemy_actors.keys():
		var e: SimOperative = world.enemy_actors[id]
		occupied[GridUtil.cell_of(e.pos)] = true
	var next_id: int = CPU_ID_BASE
	while world.enemy_actors.has(next_id):
		next_id += 1
	if world.enemy_actors.is_empty():
		for entry in map.ai_spawns:
			var sc: Vector2i = _cell_from_entry(entry)
			if not map.in_bounds(sc) or map.is_solid(sc):
				continue
			if occupied.has(sc):
				sc = _nearest_free_cell(map, sc, occupied)
			if sc == Vector2i(-1, -1):
				continue
			occupied[sc] = true
			var arch := StringName(String(entry.get("archetype", "room_anchor")))
			world.add_enemy(next_id, sc, arch, float(entry.get("facing_deg", 180.0)))
			next_id += 1
	var extra_archetypes: Array[StringName] = [&"room_anchor", &"tactical_flanker", &"tech_jammer", &"heavy_gunner"]
	var candidates: Array[Vector2i] = []
	for dz in map.defender_zones:
		for raw_c in dz.get("cells", []):
			candidates.append(_cell_from_entry(raw_c))
	for c in topo["objective_sightlines"]:
		candidates.append(c)
	for c in topo["cover_corners"]:
		candidates.append(c)
	var idx: int = 0
	var ci: int = 0
	while world.enemy_actors.size() < min_units and ci < candidates.size():
		var cand: Vector2i = candidates[ci]
		ci += 1
		if not map.in_bounds(cand) or map.is_solid(cand) or map.door_cells.has(cand) or occupied.has(cand):
			continue
		occupied[cand] = true
		var arch: StringName = extra_archetypes[idx % extra_archetypes.size()]
		world.add_enemy(next_id, cand, arch, 180.0)
		next_id += 1
		idx += 1


func _pick_focal_cell(map: GreyboxMap, topo: Dictionary, segs: Array) -> Vector2i:
	var best_focal := Vector2i(-1, -1)
	var best_count: int = -1
	var candidates: Array[Vector2i] = []
	for f in topo["fatal_funnels"]:
		candidates.append(f)
	for obj in map.objectives:
		var oc: Vector2i = _cell_from_entry(obj)
		if map.in_bounds(oc):
			candidates.append(oc)
	for c in candidates:
		var probe_claimed: Dictionary = {}
		var cf: Array[Dictionary] = SquadTactics.assign_crossfire_cells(map, c, Vector2i(1, 0), 2, probe_claimed, segs)
		if cf.size() > best_count:
			best_count = cf.size()
			best_focal = c
		if best_count >= 2 and map.door_cells.has(c):
			return c
	if best_focal != Vector2i(-1, -1):
		return best_focal
	return Vector2i(map.width_cells / 2, map.height_cells / 2)


func _pick_reserve_shift(map: GreyboxMap, from_cell: Vector2i, focal: Vector2i, claimed: Dictionary) -> Vector2i:
	for d in ORTHO:
		var nb: Vector2i = from_cell + d
		if map.in_bounds(nb) and not map.is_solid(nb) and not map.door_cells.has(nb) and not claimed.has(nb) and nb != focal:
			return nb
	return Vector2i(-1, -1)


func _pick_patrol_loop(map: GreyboxMap, start_cell: Vector2i, topo: Dictionary) -> Array[Vector2i]:
	var pts: Array[Vector2i] = []
	for c in topo["cover_corners"]:
		if c != start_cell and not map.door_cells.has(c):
			var dist: int = absi(c.x - start_cell.x) + absi(c.y - start_cell.y)
			if dist >= 2 and dist <= 6 and not GridPathfinder.find_path(map, start_cell, c).is_empty():
				pts.append(c)
				if pts.size() >= 2:
					break
	if not pts.is_empty():
		pts.append(start_cell)
	return pts


static func _nearest_free_cell(map: GreyboxMap, origin: Vector2i, occupied: Dictionary) -> Vector2i:
	for r in range(1, 5):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := Vector2i(origin.x + dx, origin.y + dy)
				if map.in_bounds(c) and not map.is_solid(c) and not map.door_cells.has(c) and not occupied.has(c):
					return c
	return Vector2i(-1, -1)


static func _cell_from_entry(entry: Variant) -> Vector2i:
	if typeof(entry) == TYPE_ARRAY:
		var arr: Array = entry
		if arr.size() >= 2:
			return Vector2i(int(float(arr[0])), int(float(arr[1])))
		return Vector2i(-1, -1)
	if typeof(entry) == TYPE_DICTIONARY:
		var d: Dictionary = entry
		if d.has("cell"):
			return _cell_from_entry(d["cell"])
		if d.has("x") and d.has("y"):
			return Vector2i(int(d["x"]), int(d["y"]))
	return Vector2i(-1, -1)


static func _cmd_move(target: Vector2i) -> AgentCommand:
	var c := AgentCommand.new()
	c.command_type = AgentCommand.CommandType.MOVE_TO_CELL
	c.target_cell = target
	return c


static func _cmd_stance(stance: StringName) -> AgentCommand:
	var c := AgentCommand.new()
	c.command_type = AgentCommand.CommandType.SET_STANCE
	c.stance_name = stance
	return c


static func _cmd_wait(code: StringName) -> AgentCommand:
	var c := AgentCommand.new()
	c.command_type = AgentCommand.CommandType.WAIT_GO_CODE
	c.go_code = code
	return c


static func _cmd_fof(bearing: int) -> AgentCommand:
	var c := AgentCommand.new()
	c.command_type = AgentCommand.CommandType.SET_FIELD_OF_FIRE
	c.bearing_deg = bearing
	return c


static func _line_clear(a: Vector2, b: Vector2, segs: Array) -> bool:
	var d := b - a
	for s in segs:
		var t: float = Visibility._ray_hit_t(a, d, s[0], s[1])
		if t > 0.000001 and t < 0.999999:
			return false
	return true
