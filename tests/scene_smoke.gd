# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
extends Node


const SCREENS: Array[String] = [
	"res://scenes/splash.tscn",
	"res://scenes/title.tscn",
	"res://scenes/campaign.tscn",
	"res://scenes/prep.tscn",
	"res://scenes/two_player.tscn",
	"res://scenes/settings.tscn",
	"res://scenes/hq.tscn",
	"res://scenes/credits.tscn",
	"res://scenes/map_editor.tscn",
	"res://scenes/planning.tscn",
]


var failures := 0


func _ready() -> void:
	print("[SMOKE] begin")
	_run.call_deferred()


func _run() -> void:
	for s in range(ScreenRouter.Stage.size()):
		var path := ScreenRouter.scene_for(s)
		var ok := path != "" and ResourceLoader.exists(path)
		_check(ok, "route stage=%d -> %s" % [s, path])
	for path in SCREENS:
		var packed := load(path) as PackedScene
		if packed == null:
			_check(false, "load " + path)
			continue
		var inst := packed.instantiate()
		get_tree().root.add_child(inst)
		for i in range(4):
			await get_tree().process_frame
		_check(inst.get_child_count() > 0, "builds children " + path)
		await _inspect(path, inst)
		get_tree().root.remove_child(inst)
		inst.queue_free()
		await get_tree().process_frame
	_check_door_route()
	_check_wall_graze_and_multifloor()
	await _check_prep_tapin_and_pvp()
	print("[SMOKE] RESULT %s failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _check_wall_graze_and_multifloor() -> void:
	var op1 := MapLoader.load_from_json("res://data/maps/op01_glass_house.json")
	var graze_wps: Array[Vector2i] = [Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2), Vector2i(6, 1), Vector2i(8, 1)]
	var repaired := RoutePlanner.repair_freehand_waypoints(op1, graze_wps)
	var grazed := RoutePlanner.plan(op1, Vector2i(2, 2), repaired)
	_check(grazed["blocked_at"] == RoutePlanner.NO_CELL and (grazed["cells"] as Array).has(Vector2i(8, 1)), "wall-graze auto-repair navigates around corner wall")
	var op5 := MapLoader.load_from_json("res://data/maps/op05_penthouse_lock.json")
	_check(op5.floor_count == 2 and not op5.stair_links.is_empty(), "op05 loads 2 floors and stair links")
	var desc := CampaignScreen.describe("res://data/maps/op05_penthouse_lock.json")
	_check(not bool(desc["practice"]), "op05 is no longer marked ground-floor practice")
	var f0 := op5.slice_map(0)
	var f1 := op5.slice_map(1)
	var stair: Dictionary = op5.stair_links[0]
	var from_cell := Vector2i(int(stair["from_cell"][0]), int(stair["from_cell"][1]))
	var to_cell := Vector2i(int(stair["to_cell"][0]), int(stair["to_cell"][1]))
	var start := Vector2i(int(op5.insertion_zones[0]["cells"][0][0]), int(op5.insertion_zones[0]["cells"][0][1]))
	var exit_cell := Vector2i.ZERO
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/op05_penthouse_lock.json"))
	for zone in raw.get("extraction_zones", []):
		if int(zone.get("floor", 0)) == 1:
			exit_cell = Vector2i(int(zone["cells"][0][0]), int(zone["cells"][0][1]))
			break
	var leg0 := RoutePlanner.plan(f0, start, [from_cell])
	var leg1 := RoutePlanner.plan(f1, to_cell, [exit_cell])
	_check(leg0["blocked_at"] == RoutePlanner.NO_CELL and leg1["blocked_at"] == RoutePlanner.NO_CELL, "op05 ground and upper floor legs path cleanly")
	var leg1_cells: Array = leg1["cells"]
	_check(not leg1_cells.is_empty() and leg1_cells[leg1_cells.size() - 1] == exit_cell, "op05 F2 path reaches the upper-floor exit from the stair cell")
	var segs := [
		{"floor": 0, "start": start, "cells": leg0["cells"], "stair_to_floor": 1, "stair_to_cell": to_cell},
		{"floor": 1, "start": to_cell, "cells": [], "stair_to_floor": -1, "stair_to_cell": Vector2i.ZERO},
	]
	var half_cmds := RoutePlanner.compile_multi_floor([f0, f1], segs)
	_check(half_cmds.size() > (leg0["cells"] as Array).size(), "compile_multi_floor handles empty untyped upper-floor cell list")
	segs[1]["cells"] = leg1["cells"]
	var cmds := RoutePlanner.compile_multi_floor([f0, f1], segs)
	var sim := SimWorld.new()
	sim.setup(op5, 17)
	sim.add_operative(0, start, cmds, 0)
	for i in range(900):
		sim.step()
		if sim.operatives[0].done:
			break
	var reached := GridUtil.cell_of(sim.operatives[0].pos)
	_check(sim.operatives[0].done and sim.operatives[0].floor_idx == 1 and reached == exit_cell, "operative uses stairs from F1 to F2 and finishes at exit (%s fl=%d)" % [str(reached), sim.operatives[0].floor_idx])


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print("[SMOKE] %s %s" % ["OK" if ok else "FAIL", what])


func _inspect(path: String, inst: Node) -> void:
	if inst is TitleScreen:
		var title := inst as TitleScreen
		_check(title.buttons.size() == 7, "title has 7 menu buttons")
		var enabled := 0
		for k in title.buttons.keys():
			var b: Button = title.buttons[k]
			_check(b.get_combined_minimum_size().y >= float(ThemeManager.TOUCH_MIN_STANDARD), "title button touch height " + String(k))
			if not b.disabled:
				enabled += 1
		_check(enabled == 7, "title enabled buttons = 7")
	elif inst is MissionPrepScreen:
		var mp := inst as MissionPrepScreen
		_check(mp.tab_buttons.size() == 5 and mp.build_loadout().size() == 2, "prep mounts 5 tabs and default 2-op loadout")
		_check(mp.toggle_operative(2) and mp.build_loadout().size() == 3, "prep toggles up to 3 operatives cleanly")
	elif inst is TwoPlayerScreen:
		var tp := inst as TwoPlayerScreen
		_check(tp.host_ip_input != null and tp.mode_button != null and tp.session != null, "two-player lobby mounts Pass & Play and LAN session")
	elif inst is CampaignScreen:
		var cs := inst as CampaignScreen
		_check(cs.missions.size() == CampaignScreen.MISSION_PATHS.size(), "campaign lists every operation")
	elif inst is SettingsScreen:
		var st := inst as SettingsScreen
		_check(st.theme_buttons.size() == ThemeManager.style_count(), "settings theme choices")
		_check(st.sliders.size() == 4, "settings volume sliders")
	elif inst is ArmoryScreen:
		var hq := inst as ArmoryScreen
		_check(hq.roster.size() == 6, "hq roster populated")
	elif inst is MapEditorScreen:
		_inspect_editor(inst as MapEditorScreen)
	elif inst is PlanningRoot:
		await _inspect_planning(inst as PlanningRoot)


func _inspect_editor(ed: MapEditorScreen) -> void:
	var c := Vector2i(5, 5)
	ed._set_tool(MapEditorState.Tool.WALL)
	_check(ed.apply_tool_at(c) and ed.state.map.solid_cells.has(c), "editor paints wall")
	ed._run_action(MapEditorState.Tool.UNDO)
	_check(not ed.state.map.solid_cells.has(c), "editor undo removes wall")
	ed._run_action(MapEditorState.Tool.REDO)
	_check(ed.state.map.solid_cells.has(c), "editor redo restores wall")
	ed._stroke = {}
	ed._set_tool(MapEditorState.Tool.ERASE)
	_check(ed.apply_tool_at(c) and not ed.state.map.solid_cells.has(c), "editor erase removes wall")
	ed._run_action(MapEditorState.Tool.UNDO)
	_check(ed.state.map.solid_cells.has(c), "editor undo restores erased wall")
	var flags := ed.run_validate()
	_check(flags.size() >= 1, "editor validate flags missing insertion")
	_check(ed.canvas != null and ed.canvas.size.x > 0.0 and ed.renderer.scale.x > 1.0, "editor canvas scaled to fit")


func _inspect_planning(pr: PlanningRoot) -> void:
	_check(pr.renderer != null and pr.renderer.enable_hd_tiles(), "HD atlas tileset loaded and rendered")
	_check(pr.prop_layer != null and pr.renderer != null and pr.prop_layer.z_index > pr.renderer.z_index, "prop layer draws above floor")
	var bound_sprites := 0
	for tok in pr.controller.tokens:
		if tok.sprite_texture != null:
			bound_sprites += 1
	_check(bound_sprites > 0, "operative sprites bound to real PNG textures")
	_check(pr.world != null and pr.world.operatives.size() == 2, "planning world has 2 operatives")
	_check(pr.squad_hud != null and pr.squad_hud.card_count() == 2, "squad hud shows red and blue cards")
	_check(pr.squad_hud.operative_button(0) != null, "squad hud has operative buttons")
	var bar := pr._hud.get_global_rect()
	var hud := pr.squad_hud.get_global_rect()
	_check(not bar.intersects(hud), "squad hud does not cover the action bar")
	_check(pr.squad_hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "squad hud root ignores input")
	_check(pr._execute_button.get_global_rect().size.y >= float(ThemeManager.TOUCH_MIN_STANDARD) - 1.0, "execute button touch height")
	_check(pr._alpha_button.disabled and pr.controller.routing_enabled, "go-codes locked and routing open while planning")
	var start: Vector2i = pr.spawn_cells[0]
	var step_x := Vector2i(1, 0) if RoutePlanner.walkable(pr.map, start + Vector2i(1, 0)) else Vector2i(0, 1)
	var wps: Array[Vector2i] = [start, start + step_x, start + step_x * 2]
	pr._on_route_committed(0, wps)
	var queued: int = pr.world.operatives[0].queue.commands.size()
	_check(queued >= 1, "drawn route reaches the sim queue (%d commands)" % queued)
	var line := pr.controller.route_line(0)
	_check(line != null and line.points.size() == queued + 1, "committed route line matches the executable cells")
	var token: OperativeToken = pr.controller.tokens[0]
	var squad := pr.squad_hud.squad_of(0)
	_check(token.callsign == pr.squad_hud.callsign(0) and token.squad_color == PlanBoard.squad_color(squad), "token displays the squad colour and callsign")
	_check(token.selected and not pr.controller.tokens[1].selected, "squad selection highlights the active token")
	_check(not pr.fog.visible, "planning hides the fog mask")
	_check(pr.world.ai.enemies.size() == pr.map.ai_spawns.size(), "mission initializes map AI spawns outside the squad")
	pr.controller.cell_tapped.emit(start)
	_check(not pr._alpha_button.disabled, "route node enables planning go-code buttons")
	pr._on_alpha_pressed()
	queued += 1
	_check(pr.world.operatives[0].queue.peek_next().command_type == AgentCommand.CommandType.WAIT_GO_CODE, "assigned go-code enters the plan")
	pr._on_execute_pressed()
	_check(SimClock.phase == SimClock.Phase.EXECUTION and not pr._alpha_button.disabled and not pr.controller.routing_enabled, "execute unlocks go-codes and locks routing")
	for i in range(3):
		await get_tree().physics_frame
	_check(pr.world.operatives[0].wait_code == &"alpha" and GridUtil.cell_of(pr.world.operatives[0].pos) == start, "operative waits at the selected route node")
	_check(pr.fog.visible and pr.fog.live_polygons_cells().size() == 2, "execution fog gets both friendly sight polygons")
	pr._on_alpha_pressed()
	for i in range(8):
		await get_tree().physics_frame
	var expected_px := pr.world.operatives[0].pos * float(SimConstants.GRID_CELL_SIZE_PX)
	var cell_center := GridUtil.cell_center_px(GridUtil.cell_of(pr.world.operatives[0].pos))
	_check(token.position.is_equal_approx(expected_px) and not expected_px.is_equal_approx(cell_center), "token tracks sub-cell simulation position")
	for i in range(32):
		await get_tree().physics_frame
	_check(pr.world.tick > 0 and GridUtil.cell_of(pr.world.operatives[0].pos) != start, "operative moves along the drawn route")
	_check(pr.world.go_codes_issued.has(&"alpha"), "go-code button reaches the sim via the tick stream")
	pr._on_reset_pressed()
	_check(SimClock.phase == SimClock.Phase.PLANNING and pr.world.tick == 0, "reset returns to planning")
	_check(GridUtil.cell_of(pr.world.operatives[0].pos) == start and pr.world.operatives[0].queue.commands.size() == queued, "reset keeps the route and restores the spawn")

	pr.set_physics_process(false)
	pr._on_execute_pressed()
	for i in range(3):
		pr._physics_process(SimWorld.DT)
	_check(pr.world.tick > 0, "retained plan can be executed again")
	pr._on_alpha_pressed()
	for i in range(120):
		pr._physics_process(SimWorld.DT)
		if pr._result_view != null:
			break
	_check(pr._result_view != null and not bool(pr._result_view.result["completed"]), "route ending before the checkpoint reports failure")
	if pr._result_view != null:
		pr._result_view.retry_requested.emit()
	_check(pr._result_view == null and SimClock.phase == SimClock.Phase.PLANNING, "result replan clears the overlay and restores planning")

	var checkpoint := MapEditorValidator.cell_of(pr.map.objectives[0])
	var exit_cell := MapEditorValidator.cell_of(pr.map.extraction_zones[0]["cells"][0])
	var mission_route: Array[Vector2i] = [start, checkpoint, exit_cell]
	pr._on_route_committed(0, mission_route)
	pr._on_execute_pressed()
	for i in range(1200):
		pr._physics_process(SimWorld.DT)
		if pr._result_view != null:
			break
	_check(pr._result_view != null and bool(pr._result_view.result["completed"]), "authored campaign checkpoint and exit complete the mission")
	if pr._result_view != null:
		var title := pr._result_view.find_child("ResultTitle", true, false) as Label
		_check(title != null and title.text == "OPERATION COMPLETE", "successful operation renders a result screen")
		_check(pr.props != null and pr.loupe != null, "planning mounts props and loupe")
		_check(pr._result_view.scrubber != null, "result renders replay scrubber")
		pr.scrub_replay_to_tick(10)
		_check(pr.world.tick == 10, "replay scrubber rewinds to tick 10")
	_inspect_contacts(pr)
	_inspect_enemy_fire(pr)
	_inspect_node_orders(pr)
	_inspect_view3d(pr)


func _inspect_view3d(pr: PlanningRoot) -> void:
	_check(pr.view3d != null, "2.5D view layer mounted")
	_check(WorldView3D.cell_to_world(Vector2i(2, 3), 1) == Vector3(3.0, 3.2, 4.5), "grid projection matches 5-ft scale")
	_check(pr._view_bar != null and pr._view_bar.get_child_count() == 4, "view controls expose view/yaw/pitch buttons")
	var before_hash: String = pr.world.state_hash()
	var before_tick: int = pr.world.tick
	pr._toggle_view3d()
	_check(pr.view3d.is_active() and not pr.renderer.visible, "2.5D toggle hides classic map layer")
	_check(pr._view_button.text == "2.5D", "view button reflects 2.5D mode")
	pr._on_yaw_cw()
	_check(is_equal_approx(pr.view3d.camera.target_yaw, 90.0), "yaw snap lands on 90 degrees")
	pr._on_yaw_ccw()
	_check(is_equal_approx(pr.view3d.camera.target_yaw, 0.0), "yaw snap returns to zero")
	pr._on_pitch_cycle()
	_check(pr.view3d.camera.tier == 2, "pitch cycles to eye-level tier")
	pr._on_pitch_cycle()
	pr._on_pitch_cycle()
	_check(pr.view3d.camera.tier == 1, "pitch cycles back to tactical tier")
	var floors: Dictionary = pr.view3d._floor_meshes
	var entry: Dictionary = floors[0]
	var plates := entry.get("floor") as MultiMeshInstance3D
	var walls := entry.get("walls") as MultiMeshInstance3D
	_check(plates != null and plates.multimesh.instance_count == pr.map.width_cells * pr.map.height_cells, "floor plates batched in one multimesh")
	_check(walls != null and walls.multimesh.instance_count == 250, "walls batched in one multimesh")
	_check(pr.world.tick == before_tick and pr.world.state_hash() == before_hash, "view layer never mutates sim state")
	pr._toggle_view3d()
	_check(not pr.view3d.is_active() and pr.renderer.visible, "view toggle restores classic blueprint")


func _plan_has(pr: PlanningRoot, op_id: int, kind: int, field: String = "", value: Variant = null) -> bool:
	for c in pr.plans.get(op_id, []):
		var cmd: AgentCommand = c
		if int(cmd.command_type) != kind:
			continue
		if field == "" or cmd.get(field) == value:
			return true
	return false


func _inspect_node_orders(pr: PlanningRoot) -> void:
	pr._on_reset_pressed()
	var start: Vector2i = pr.spawn_cells[0]
	var route: Array[Vector2i] = [start, start + Vector2i(1, 0), start + Vector2i(2, 0)]
	pr._on_route_committed(0, route)
	_check(not pr._node_menu.visible, "node menu hidden until a waypoint is tapped")
	var node := start + Vector2i(1, 0)
	pr._on_route_node_tapped(node)
	_check(pr._node_menu.visible and pr._selected_node == node, "tapping a waypoint opens the command node menu")
	pr._set_node_order("stance", &"blitz")
	_check(_plan_has(pr, 0, AgentCommand.CommandType.SET_STANCE, "stance_name", &"blitz"), "stance order compiles into the plan")
	var blitz_btn: Button = pr._node_menu.find_child("Node_stance_BLITZ", true, false)
	_check(blitz_btn != null and blitz_btn.button_pressed, "active stance shows as pressed")
	pr._set_node_order("action", AgentCommand.ActionKind.FLASHBANG)
	_check(_plan_has(pr, 0, AgentCommand.CommandType.PERFORM_ACTION, "action_kind", AgentCommand.ActionKind.FLASHBANG), "action order compiles into the plan")
	pr._set_node_order("fof", 90)
	_check(_plan_has(pr, 0, AgentCommand.CommandType.SET_FIELD_OF_FIRE, "bearing_deg", 90), "facing order compiles into the plan")
	_check(pr.node_summary(0, node).contains("BLITZ") and pr.node_summary(0, node).contains("FLASHBANG"), "status summarises the node orders")
	var line := pr.controller.route_line(0)
	var marked := false
	for child in line.get_children():
		if child is Label and (child as Label).text.contains("*"):
			marked = true
	_check(marked, "route shows a marker on the ordered node")
	pr._set_node_order("stance", &"blitz")
	_check(not _plan_has(pr, 0, AgentCommand.CommandType.SET_STANCE), "tapping the active stance again removes it")
	pr._clear_node()
	_check(pr.node_order(0, node).is_empty() and not _plan_has(pr, 0, AgentCommand.CommandType.PERFORM_ACTION, "action_kind", AgentCommand.ActionKind.FLASHBANG), "clear node removes every order")
	pr._set_node_order("mode", &"advance")
	pr._on_execute_pressed()
	_check(SimClock.phase == SimClock.Phase.EXECUTION and not pr._node_menu.visible, "node menu closes when execution starts")
	_check(pr.world.operatives[0].queue.commands.size() == (pr.plans[0] as Array).size(), "the executing world runs the compiled node orders")
	pr._on_reset_pressed()
	pr.plans.clear()
	pr.route_cells.clear()
	pr._route_orders.clear()
	pr._route_waits.clear()
	pr._on_reset_pressed()


func _inspect_enemy_fire(pr: PlanningRoot) -> void:
	pr._on_reset_pressed()
	for i in range(pr.spawn_cells.size()):
		var hold := AgentCommand.new()
		hold.command_type = AgentCommand.CommandType.WAIT_GO_CODE
		hold.go_code = &"delta"
		var plan: Array[AgentCommand] = [hold]
		var cells: Array[Vector2i] = [pr.spawn_cells[i]]
		pr.plans[i] = plan
		pr.route_cells[i] = cells
	pr._rebuild_world()
	var gunner_cell := Vector2i(1, 6)
	var aim := CombatSystem.angle_to(Vector2(gunner_cell) + Vector2(0.5, 0.5), Vector2(2.5, 3.0))
	var gunner := pr.world.add_enemy(50, gunner_cell, &"heavy_gunner", aim)
	pr._on_execute_pressed()
	_check(SimClock.phase == SimClock.Phase.EXECUTION, "execute starts with holding routes")
	for i in range(900):
		pr._physics_process(SimWorld.DT)
		if pr._result_view != null:
			break
	var gunner_shots := 0
	var friendly_shots := 0
	for e in pr.world.journal:
		if StringName(e["ev"]) == &"shot":
			if int(e["op"]) == 50:
				gunner_shots += 1
			else:
				friendly_shots += 1
	_check(gunner_shots > 0 and friendly_shots == 0, "enemy behind the squad fires and the squad cannot return fire (%d shots)" % gunner_shots)
	var all_kia := true
	for o in pr.world.operatives:
		all_kia = all_kia and not o.is_alive() and o.health == &"kia"
	_check(all_kia and gunner.is_alive(), "enemy fire kills every operative")
	_check(pr._result_view != null and not bool(pr._result_view.result["completed"]) and String(pr._result_view.result["reason"]) == "No operatives remaining.", "losing the squad to enemy fire fails the operation")
	var tok: OperativeToken = pr.controller.tokens[0]
	_check(tok.status == &"kia", "dead operative token shows KIA")
	_check(pr.world.ai.acoustic_rings().size() == gunner_shots, "gunfire is recorded as acoustic events for the overlay rings")
	if pr._result_view != null:
		pr._result_view.retry_requested.emit()
	pr.plans.clear()
	pr.route_cells.clear()
	pr._on_reset_pressed()
	_check(pr.world.operatives.size() == pr.spawn_cells.size() and pr.world.operatives[0].is_alive(), "replan after defeat restores a living squad")


func _inspect_contacts(pr: PlanningRoot) -> void:
	pr._on_reset_pressed()
	pr.world.setup(GreyboxMap.build_default(), 1)
	var commands: Array[AgentCommand] = []
	pr.world.add_operative(0, Vector2i(2, 3), commands)
	var enemy := pr.world.add_enemy(9, Vector2i(3, 3), &"")
	pr._update_fog()
	_check(pr.overlay.visible_contacts().has(9), "registered enemy in sight is a visible contact")
	var last_seen := enemy.pos
	enemy.pos = Vector2(10.5, 3.5)
	pr.world.tick += 60
	pr._update_fog()
	var contact: Dictionary = pr.overlay.contacts.get(9, {})
	_check(pr.overlay.lkp_contacts().has(9) and contact.get("pos") == last_seen, "hidden enemy retains only the last seen position")
	_check(is_equal_approx(pr.overlay.seconds_since_contact(9), 1.0), "contact age follows simulation ticks")
	pr._on_reset_pressed()
	_check(pr.overlay.contacts.is_empty() and not pr.fog.visible, "reset clears contacts and hides the fog mask")


func _check_door_route() -> void:
	var map := GreyboxMap.build_default()
	var start := Vector2i(7, 6)
	var door := Vector2i(8, 6)
	var goal := Vector2i(9, 6)
	var waypoints: Array[Vector2i] = [door, goal]
	var route := RoutePlanner.plan(map, start, waypoints)
	var commands: Array[AgentCommand] = route["commands"]
	_check(commands.size() == 3 and commands[0].command_type == AgentCommand.CommandType.PERFORM_ACTION, "closed-door route queues an action before moving")
	var sim := SimWorld.new()
	sim.setup(map, 1)
	sim.add_operative(0, start, commands)
	for i in range(250):
		sim.step()
		if sim.operatives[0].done:
			break
	_check(sim.operatives[0].done and GridUtil.cell_of(sim.operatives[0].pos) == goal, "closed-door route reaches the far side")


func _check_prep_tapin_and_pvp() -> void:
	ScreenRouter.set_param("map_path", "res://data/maps/op01_glass_house.json")
	ScreenRouter.set_param("mission_loadout", [
		{"roster_id": 0, "codename": "VANGUARD", "squad": "red", "caliber": "7.62", "armor_class": "heavy", "heartbeat_radius": 4},
		{"roster_id": 1, "codename": "VECTOR", "squad": "blue", "caliber": "5.56", "armor_class": "medium", "heartbeat_radius": 2},
		{"roster_id": 2, "codename": "SLEDGE", "squad": "green", "caliber": "9mm", "armor_class": "light", "heartbeat_radius": 0},
	])
	var packed := load("res://scenes/planning.tscn") as PackedScene
	var pr := packed.instantiate() as PlanningRoot
	get_tree().root.add_child(pr)
	for i in range(4):
		await get_tree().process_frame
	_check(pr.world.operatives.size() == 3, "mission_loadout spawns 3 operatives")
	_check(pr.world.operatives[0].armor_class == &"heavy" and pr.world.operatives[0].heartbeat_radius == 4, "mission_loadout applies armor and heartbeat sensor")
	pr.set_physics_process(false)
	var start0: Vector2i = pr.spawn_cells[0]
	var route0: Array[Vector2i] = [start0, start0 + Vector2i(1, 0)]
	pr._on_route_committed(0, route0)
	pr._on_execute_pressed()
	pr.squad_hud.touch_operative(0)
	var tap_target := start0 + Vector2i(2, 0)
	pr._on_execution_cell_tapped(tap_target)
	for i in range(180):
		pr._physics_process(SimWorld.DT)
		if GridUtil.cell_of(pr.world.operatives[0].pos) == tap_target:
			break
	_check(pr.world.tapin_points == SimConstants.TAPIN_COMMAND_POINTS_MAX - 1, "live Tap-In spends 1 CP")
	_check(pr.world.override_stream.size() == 1 and pr.world.override_stream[0].use_slot, "live Tap-In records use_slot OverrideCommand")
	_check(GridUtil.cell_of(pr.world.operatives[0].pos) == tap_target, "live Tap-In redirects operative to tapped cell")
	SimClock.reset_to_planning()
	get_tree().root.remove_child(pr)
	pr.queue_free()
	await get_tree().process_frame

	var cr := CommitReveal.new()
	var commitment := cr.commit("{\"0\":[1,2]}", "salt42")
	_check(commitment.length() == 64 and cr.verify("{\"0\":[1,2]}", "salt42", commitment) and not cr.verify("{\"0\":[9]}", "salt42", commitment), "CommitReveal SHA-256 verify holds")
	cr.free()
	var net := LockstepSession.new()
	get_tree().root.add_child(net)
	var host_err: int = net.host_on_port(0, 17605)
	_check(host_err == OK and net.session_active, "LockstepSession ENet create_server opens UDP port")
	net.close_session()
	get_tree().root.remove_child(net)
	net.free()

	ScreenRouter.set_param("map_path", "res://data/maps/op01_glass_house.json")
	ScreenRouter.set_param("two_player_config", {"transport": "pass_play", "mode": "pvp", "seed": 2026})
	var pvp_pr := packed.instantiate() as PlanningRoot
	get_tree().root.add_child(pvp_pr)
	for i in range(4):
		await get_tree().process_frame
	_check(pvp_pr.world.operatives.size() == 4 and pvp_pr.world.operatives[2].faction_id == 1, "Pass-and-Play PvP spawns Faction 0 Breachers and Faction 1 Defenders")
	var p1_start := pvp_pr.spawn_cells[0]
	pvp_pr._on_route_committed(0, [p1_start, p1_start + Vector2i(1, 0)])
	pvp_pr._on_execute_pressed()
	_check(pvp_pr._pass_play_stage == 1 and not pvp_pr._p1_commitment.is_empty(), "COMMIT P1 hashes P1 routes and switches turn to P2")
	var p2_start := pvp_pr.spawn_cells[2]
	pvp_pr._on_route_committed(2, [p2_start, p2_start + Vector2i(1, 0)])
	pvp_pr._on_execute_pressed()
	_check(SimClock.phase == SimClock.Phase.EXECUTION, "EXEC P2 verifies P1 commitment and enters 60 Hz execution")
	SimClock.reset_to_planning()
	get_tree().root.remove_child(pvp_pr)
	pvp_pr.queue_free()
	await get_tree().process_frame
	ScreenRouter.clear_param("mission_loadout")
	ScreenRouter.clear_param("two_player_config")
