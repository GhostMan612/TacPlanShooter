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
	pr._on_execute_pressed()
	_check(SimClock.phase == SimClock.Phase.EXECUTION and not pr._alpha_button.disabled and not pr.controller.routing_enabled, "execute unlocks go-codes and locks routing")
	pr._on_alpha_pressed()
	for i in range(40):
		await get_tree().physics_frame
	_check(pr.world.tick > 0 and GridUtil.cell_of(pr.world.operatives[0].pos) != start, "operative moves along the drawn route")
	_check(pr.world.go_codes_issued.has(&"alpha"), "go-code button reaches the sim via the tick stream")
	pr._on_reset_pressed()
	_check(SimClock.phase == SimClock.Phase.PLANNING and pr.world.tick == 0, "reset returns to planning")
	_check(GridUtil.cell_of(pr.world.operatives[0].pos) == start and pr.world.operatives[0].queue.commands.size() == queued, "reset keeps the route and restores the spawn")
