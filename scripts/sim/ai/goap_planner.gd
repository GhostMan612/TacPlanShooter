# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name GoapPlanner
extends RefCounted

const REPLAN_INTERVAL_TICKS := 12


static func should_replan(tick: int, unit_id: int) -> bool:
	return (tick + absi(unit_id)) % REPLAN_INTERVAL_TICKS == 0


static func select_goal(state_mask: int, role: int, max_depth: int = 4) -> Dictionary:
	if (state_mask & GoapActions.F_SPOTTED_BY_DRONE) != 0:
		return {"name": &"anti_drone", "goal_mask": GoapActions.F_DRONE_HANDLED | GoapActions.F_REPOSITIONED}
	if (state_mask & GoapActions.F_AMMO_LOW) != 0:
		var reload_goal: int = GoapActions.F_AMMO_FULL
		if max_depth >= 4:
			reload_goal |= GoapActions.F_CALLOUT_SENT | GoapActions.F_PRE_AIMED
		elif max_depth == 3:
			reload_goal |= GoapActions.F_PRE_AIMED
		return {"name": &"tactical_reload", "goal_mask": reload_goal}
	if (state_mask & GoapActions.F_HEAR_BREACH) != 0 and (state_mask & GoapActions.F_TARGET_VISIBLE) == 0:
		return {"name": &"breach_counter", "goal_mask": GoapActions.F_AT_TACTICAL_CELL | GoapActions.F_PRE_AIMED}
	if role == int(SquadCoordinator.Role.SUPPRESSOR) and (state_mask & GoapActions.F_LKP_KNOWN) != 0:
		return {"name": &"suppress_lkp", "goal_mask": GoapActions.F_ALLY_SUPPRESSING | GoapActions.F_TARGET_ENGAGED}
	if role == int(SquadCoordinator.Role.FLANKER) and (state_mask & GoapActions.F_LKP_KNOWN) != 0 and (state_mask & GoapActions.F_FLANK_OPEN) != 0 and ((state_mask & GoapActions.F_ALLY_SUPPRESSING) != 0 or (state_mask & GoapActions.F_TARGET_VISIBLE) == 0):
		return {"name": &"flank_bound", "goal_mask": GoapActions.F_BOUNDED | GoapActions.F_TARGET_ENGAGED}
	if (state_mask & GoapActions.F_LKP_KNOWN) != 0 and (state_mask & GoapActions.F_TARGET_IN_COVER) != 0 and ((state_mask & GoapActions.F_HAS_FLASHBANG) != 0 or ((state_mask & GoapActions.F_HAS_FRAG) != 0 and (state_mask & GoapActions.F_HOSTAGE_NEAR) == 0)):
		return {"name": &"flush_cover", "goal_mask": GoapActions.F_TARGET_FLUSHED | GoapActions.F_TARGET_ENGAGED}
	if (state_mask & GoapActions.F_TARGET_VISIBLE) != 0:
		return {"name": &"engage_visible", "goal_mask": GoapActions.F_TARGET_ENGAGED}
	if (state_mask & GoapActions.F_UNDER_SUPPRESSION) != 0 and (state_mask & GoapActions.F_IN_COVER) == 0:
		return {"name": &"take_cover", "goal_mask": GoapActions.F_IN_COVER}
	if (state_mask & GoapActions.F_LKP_KNOWN) != 0:
		return {"name": &"suppress_lkp", "goal_mask": GoapActions.F_TARGET_ENGAGED}
	return {"name": &"idle", "goal_mask": 0}


static func plan(initial_mask: int, goal_mask: int, max_depth: int = 4, actions: Array = []) -> Array[StringName]:
	var result: Array[StringName] = []
	if goal_mask == 0 or (initial_mask & goal_mask) == goal_mask:
		return result
	var catalog: Array = actions if not actions.is_empty() else GoapActions.build_catalog(true, true)
	var depth_limit: int = clampi(max_depth, 1, 4)
	var open_nodes: Array = [{
		"mask": initial_mask,
		"g": 0,
		"f": _unsatisfied_count(initial_mask, goal_mask),
		"steps": result,
		"tie": 0,
	}]
	var best_g: Dictionary = {initial_mask: 0}
	while not open_nodes.is_empty():
		var best_idx: int = 0
		for i in range(1, open_nodes.size()):
			if _node_better(open_nodes[i], open_nodes[best_idx]):
				best_idx = i
		var cur: Dictionary = open_nodes[best_idx]
		open_nodes.remove_at(best_idx)
		var cur_mask: int = int(cur["mask"])
		if (cur_mask & goal_mask) == goal_mask:
			var done_steps: Array[StringName] = []
			for s in cur["steps"]:
				done_steps.append(s)
			return done_steps
		var cur_steps: Array[StringName] = cur["steps"]
		if cur_steps.size() >= depth_limit:
			continue
		for ai in range(catalog.size()):
			var act: Dictionary = catalog[ai]
			var pre_pos: int = int(act["pre_pos"])
			var pre_neg: int = int(act["pre_neg"])
			if (cur_mask & pre_pos) != pre_pos or (cur_mask & pre_neg) != 0:
				continue
			var nxt_mask: int = (cur_mask & (~int(act["del"]))) | int(act["add"])
			if nxt_mask == cur_mask:
				continue
			var ng: int = int(cur["g"]) + int(act["cost"])
			if best_g.has(nxt_mask) and int(best_g[nxt_mask]) <= ng:
				continue
			best_g[nxt_mask] = ng
			var nxt_steps: Array[StringName] = cur_steps.duplicate()
			nxt_steps.append(StringName(act["name"]))
			var h: int = _unsatisfied_count(nxt_mask, goal_mask)
			open_nodes.append({
				"mask": nxt_mask,
				"g": ng,
				"f": ng + h,
				"steps": nxt_steps,
				"tie": ai,
			})
	return result


static func plan_for_unit(state_mask: int, role: int, max_depth: int = 4, allow_grenades: bool = true, allow_smoke: bool = true) -> Dictionary:
	var sel: Dictionary = select_goal(state_mask, role, max_depth)
	var goal_name: StringName = sel["name"]
	var goal_mask: int = int(sel["goal_mask"])
	var catalog: Array[Dictionary] = GoapActions.build_catalog(allow_grenades, allow_smoke)
	var steps: Array[StringName] = plan(state_mask, goal_mask, max_depth, catalog)
	return {"goal": goal_name, "actions": steps}


static func _unsatisfied_count(mask: int, goal_mask: int) -> int:
	var missing: int = goal_mask & (~mask)
	var count: int = 0
	for b in range(26):
		if (missing & (1 << b)) != 0:
			count += 1
	return count


static func _node_better(a: Dictionary, b: Dictionary) -> bool:
	var fa: int = int(a["f"])
	var fb: int = int(b["f"])
	if fa != fb:
		return fa < fb
	var ga: int = int(a["g"])
	var gb: int = int(b["g"])
	if ga != gb:
		return ga < gb
	var sa: int = (a["steps"] as Array).size()
	var sb: int = (b["steps"] as Array).size()
	if sa != sb:
		return sa < sb
	return int(a["tie"]) < int(b["tie"])
