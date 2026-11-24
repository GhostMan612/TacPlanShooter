# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
extends Node


const SCREENS: Array[String] = [
	"res://scenes/splash.tscn",
	"res://scenes/title.tscn",
	"res://scenes/campaign.tscn",
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
	print("[SMOKE] RESULT %s failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


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
		_check(enabled == 6, "title enabled buttons = 6")
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
	var tok: OperativeToken = pr.controller.tokens[0]
	_check(tok.callsign == pr.squad_hud.callsign(0) and tok.callsign != "" and tok.squad_color == PlanBoard.squad_color(pr.squad_hud.squad_of(0)), "token shows squad colour and callsign %s" % tok.callsign)
	_check(not pr.fog.active and not pr.fog.visible, "fog hidden while planning")
	pr._on_execute_pressed()
	_check(SimClock.phase == SimClock.Phase.EXECUTION and not pr._alpha_button.disabled and not pr.controller.routing_enabled, "execute unlocks go-codes and locks routing")
	var rebuilds_at_exec := pr.fog_segment_rebuilds
	var computes_at_exec := pr.fog_poly_computes
	pr._on_alpha_pressed()
	for i in range(40):
		await get_tree().physics_frame
	_check(pr.world.tick > 0 and GridUtil.cell_of(pr.world.operatives[0].pos) != start, "operative moves along the drawn route")
	_check(pr.world.go_codes_issued.has(&"alpha"), "go-code button reaches the sim via the tick stream")
	_check(pr.fog.active and pr.fog.visible and pr.fog.shape_count() == 2, "fog buffer active with one sight shape per friendly (%d)" % pr.fog.shape_count())
	_check(pr.fog.pool_size() == 4, "fog reuses a fixed polygon pool (%d)" % pr.fog.pool_size())
	_check(pr.fog_segment_rebuilds == rebuilds_at_exec, "wall segments cached while doors are unchanged")
	var computes := pr.fog_poly_computes - computes_at_exec
	_check(computes > 0 and computes <= 41, "sight polygons cached for stationary operatives (%d computes in 40 ticks)" % computes)
	var op0 := pr.world.operatives[0]
	_check(tok.position.distance_to(op0.pos * float(SimConstants.GRID_CELL_SIZE_PX)) < 0.001, "token tracks the exact sim position")
	pr._on_reset_pressed()
	_check(SimClock.phase == SimClock.Phase.PLANNING and pr.world.tick == 0, "reset returns to planning")
	_check(GridUtil.cell_of(pr.world.operatives[0].pos) == start and pr.world.operatives[0].queue.commands.size() == queued, "reset keeps the route and restores the spawn")
	_check(not pr.fog.active and pr.overlay.contacts.is_empty(), "reset hides fog and clears contacts")
	_inspect_hostiles(pr)
	_probe_fog_perf(pr)


func _inspect_hostiles(pr: PlanningRoot) -> void:
	var none: Array[AgentCommand] = []
	pr.world.add_operative(9, Vector2i(3, 3), none)
	var hostile: SimOperative = pr.world.operatives[pr.world.operatives.size() - 1]
	hostile.faction_id = 1
	pr._update_fog()
	_check(pr.overlay.visible_contacts().has(9), "hostile in line of sight is a live contact")
	_check(pr.squad_hud.card_count() == 2, "hostiles never appear in the squad HUD")
	hostile.pos = Vector2(7.5, 5.5)
	pr._update_fog()
	_check(pr.overlay.lkp_contacts().has(9) and not pr.overlay.visible_contacts().has(9), "hostile behind a wall becomes a last-known-position ghost")
	var lkp: Vector2 = pr.overlay.contacts[9]["pos"]
	_check(lkp.distance_to(Vector2(3.5, 3.5)) < 0.001, "LKP keeps the last seen position, not the true one")
	pr._on_reset_pressed()
	_check(pr.overlay.contacts.is_empty() and pr.world.operatives.size() == 2, "reset clears injected hostile and contacts")


func _probe_fog_perf(pr: PlanningRoot) -> void:
	var runs := 120
	var t0 := Time.get_ticks_usec()
	for i in range(runs):
		pr._sight_cache.clear()
		pr._update_fog()
	var avg_us := float(Time.get_ticks_usec() - t0) / float(runs)
	print("[SMOKE] perf fog_update uncached avg_us=%.1f segs=%d" % [avg_us, pr._segs.size()])
	_check(avg_us < 8000.0, "uncached fog update under 8 ms on CI (%.0f us)" % avg_us)
