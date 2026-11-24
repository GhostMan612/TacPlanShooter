# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name PlanningRoot
extends Node2D

const DEV_SEED := 1337

var map: GreyboxMap = null
var renderer: MapRenderer = null
var squad_hud: SquadHud = null
var _tm: ThemeManager = null
var camera: MissionCamera = null
var controller: PlanningController = null
var world: SimWorld = null
var fog: FogLayer = null
var prep_flow: MissionPrepFlow = null
var local_faction_id: int = 0

var squads := SquadConfig.new()
var map_source := ""
var _hud: HBoxContainer = null
var _menu_button: Button = null
var _execute_button: Button = null
var _alpha_button: Button = null
var _bravo_button: Button = null
var _charlie_button: Button = null
var _delta_button: Button = null
var _reset_button: Button = null
var _hud_canvas: CanvasLayer = null


func _ready() -> void:
	var phase_name := "PLANNING" if SimClock.phase == SimClock.Phase.PLANNING else "EXECUTION"
	var method: String = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	print("[TacPlan] boot OK phase=%s fps_cap=%d renderer=%s ticks_per_sec=%d" % [
		phase_name,
		Engine.max_fps,
		method,
		Engine.physics_ticks_per_second,
	])
	map = _load_selected_map()
	_apply_theme()
	renderer = MapRenderer.new()
	renderer.apply_palette(_tm.palette())
	renderer.setup(map)
	add_child(renderer)
	fog = FogLayer.new()
	fog.setup(map)
	add_child(fog)
	fog.visible = false
	prep_flow = MissionPrepFlow.new()
	add_child(prep_flow)
	for spec in [[0, Vector2i(2, 2)], [1, Vector2i(13, 2)]]:
		var token := OperativeToken.new(int(spec[0]))
		token.position = GridUtil.cell_center_px(Vector2i(spec[1]))
		token.z_index = 1
		add_child(token)
	camera = MissionCamera.new()
	add_child(camera)
	camera.configure_for_map(
		Vector2(map.width_cells, map.height_cells) * float(SimConstants.GRID_CELL_SIZE_PX),
		get_viewport_rect().size
	)
	camera.make_current()
	controller = PlanningController.new()
	controller.camera = camera
	controller.line_container = self
	for child in get_children():
		if child is OperativeToken:
			controller.tokens.append(child as OperativeToken)
	add_child(controller)
	get_viewport().size_changed.connect(_on_viewport_resized)
	world = SimWorld.new()
	world.setup(map, DEV_SEED)
	world.add_operative(0, Vector2i(2, 2), _demo_plan_op0())
	world.add_operative(1, Vector2i(13, 2), _demo_plan_op1())
	squads.add_member(&"red", 0)
	squads.add_member(&"blue", 1)
	_setup_hud()
	print("[TacPlan] planning map=%s size=%dx%d" % [map_source, map.width_cells, map.height_cells])


func _load_selected_map() -> GreyboxMap:
	var inline_json: Variant = ScreenRouter.get_param("map_json", null)
	ScreenRouter.clear_param("map_json")
	if typeof(inline_json) == TYPE_STRING and String(inline_json) != "":
		var custom := MapLoader.load_from_string(String(inline_json))
		if custom.width_cells > 0 and custom.height_cells > 0:
			map_source = "editor_buffer"
			return custom
	var path := String(ScreenRouter.get_param("map_path", ScreenRouter.DEFAULT_MAP_PATH))
	if FileAccess.file_exists(path):
		var loaded := MapLoader.load_from_json(path)
		if loaded.width_cells > 0 and loaded.height_cells > 0:
			map_source = path
			return loaded
	map_source = "greybox_default"
	return GreyboxMap.build_default()


func _on_viewport_resized() -> void:
	if camera != null:
		camera.set_viewport_size(get_viewport_rect().size)
	_place_hud()


func _physics_process(_delta: float) -> void:
	if world != null and SimClock.phase == SimClock.Phase.EXECUTION:
		world.step()
		_sync_tokens()
		_update_fog()
		if squad_hud != null:
			squad_hud.refresh(world)
		_maybe_aar()


func _draw() -> void:
	queue_redraw()
	if world == null or map == null:
		return
	var ticks := int(world.tick)
	for ring in world.ai.acoustic_rings():
		var age := ticks - int(ring["tick"])
		if age > 24:
			continue
		var center := GridUtil.cell_center_px(ring["cell"])
		var a := 1.0 - (float(age) / 24.0)
		draw_circle(center, 20.0 + a * 10.0, Color(1.0, 0.7, 0.0, a * 0.8))
		draw_circle(center, 38.0, Color(1.0, 0.4, 0.0, a * 0.5))


func _sync_tokens() -> void:
	if world == null or controller == null:
		return
	for o in world.operatives:
		for token in controller.tokens:
			if token.op_id == o.id:
				token.position = GridUtil.cell_center_px(GridUtil.cell_of(o.pos))


func _update_fog() -> void:
	if fog == null or map == null or world == null:
		return
	fog.visible = true
	var segs := map.get_wall_segments()
	var live_polys := []
	for o in world.operatives:
		if o.faction_id != local_faction_id:
			continue
		var poly := Visibility.compute_polygon(o.pos, segs, SimConstants.LOS_VERTEX_EPSILON_RAD)
		if poly.size() >= 3:
			live_polys.append(poly)
			if fog.poly_contains(o.pos, poly):
				fog.mark_visible(poly)
	for d in world.drones:
		if d.destroyed:
			continue
		var dpoly := Visibility.compute_polygon(d.pos, segs, SimConstants.LOS_VERTEX_EPSILON_RAD)
		if dpoly.size() >= 3:
			live_polys.append(dpoly)
	fog.rebuild(live_polys)


func _apply_theme() -> void:
	_tm = ThemeManager.apply_saved()
	_tm.theme_changed.connect(_on_theme_changed)


func _on_theme_changed(pal: Dictionary) -> void:
	if renderer != null:
		renderer.apply_palette(pal)
	if squad_hud != null:
		squad_hud.apply_palette(pal)


func _setup_hud() -> void:
	var settings := ThemeManager.load_settings()
	_hud_canvas = CanvasLayer.new()
	add_child(_hud_canvas)
	_menu_button = UiKit.button("< MENU", _go_back, settings)
	_menu_button.size_flags_horizontal = Control.SIZE_FILL
	_hud_canvas.add_child(_menu_button)
	_hud = HBoxContainer.new()
	_hud.name = "ActionBar"
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_canvas.add_child(_hud)
	_execute_button = UiKit.button("EXECUTE", _on_execute_pressed, settings)
	_alpha_button = UiKit.button("A", _on_alpha_pressed, settings)
	_bravo_button = UiKit.button("B", _on_bravo_pressed, settings)
	_charlie_button = UiKit.button("C", _on_charlie_pressed, settings)
	_delta_button = UiKit.button("D", _on_delta_pressed, settings)
	_reset_button = UiKit.button("RESET", _on_reset_pressed, settings)
	_execute_button.size_flags_stretch_ratio = 2.0
	_reset_button.size_flags_stretch_ratio = 1.6
	for b in [_execute_button, _alpha_button, _bravo_button, _charlie_button, _delta_button, _reset_button]:
		_hud.add_child(b)
	squad_hud = SquadHud.new()
	squad_hud.squads = squads
	_hud_canvas.add_child(squad_hud)
	squad_hud.apply_palette(_tm.palette())
	squad_hud.refresh(world)
	for c in [_menu_button, _hud, squad_hud]:
		(c as Control).theme = _tm.applied_theme
	_place_hud()


func _place_hud() -> void:
	if _hud == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var bar_h := float(ThemeManager.touch_min(_tm != null and _tm.accessible_scaling))
	var margin := 24.0
	_hud.position = Vector2(margin, vp.y - bar_h - margin)
	_hud.size = Vector2(vp.x - margin * 2.0, bar_h)
	if _menu_button != null:
		_menu_button.position = Vector2(margin, 72.0)
		_menu_button.size = Vector2(280.0, bar_h)
	if squad_hud != null:
		squad_hud.place(Rect2(Vector2(margin, vp.y - bar_h - margin * 2.0 - SquadHud.HEIGHT_PX), Vector2(vp.x - margin * 2.0, SquadHud.HEIGHT_PX)))


func _go_back() -> void:
	if SimClock.phase == SimClock.Phase.EXECUTION:
		SimClock.reset_to_planning()
	var target := int(ScreenRouter.get_param("return_stage", int(ScreenRouter.Stage.TITLE)))
	ScreenRouter.goto_stage(target)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _unhandled_key_input(event: InputEvent) -> void:
	if UiKit.is_back_event(event):
		_go_back()


func _on_execute_pressed() -> void:
	if world == null or SimClock.phase != SimClock.Phase.PLANNING:
		return
	SimClock.start_execution()
	_execute_button.disabled = true


func _on_alpha_pressed() -> void:
	if world != null:
		world.issue_go_code(&"alpha")
		print("[TacPlan] go_code issued: alpha")


func _on_bravo_pressed() -> void:
	if world != null:
		world.issue_go_code(&"bravo")
		print("[TacPlan] go_code issued: bravo")


func _on_charlie_pressed() -> void:
	if world != null:
		world.issue_go_code(&"charlie")
		print("[TacPlan] go_code issued: charlie")


func _on_delta_pressed() -> void:
	if world != null:
		world.issue_go_code(&"delta")
		print("[TacPlan] go_code issued: delta")


func _on_reset_pressed() -> void:
	if world == null:
		return
	world.setup(map, DEV_SEED)
	world.add_operative(0, Vector2i(2, 2), _demo_plan_op0())
	world.add_operative(1, Vector2i(13, 2), _demo_plan_op1())
	SimClock.reset_to_planning()
	_execute_button.disabled = false
	fog.reset_fog()
	_sync_tokens()
	if squad_hud != null:
		squad_hud.refresh(world)


func _maybe_aar() -> void:
	if world == null:
		return
	var all_down := true
	for o in world.operatives:
		if o.is_alive():
			all_down = false
			break
	if not all_down:
		return
	var aar := AarScreen.new()
	aar.world = world
	add_child(aar)
	SimClock.reset_to_planning()
	if _execute_button != null:
		_execute_button.disabled = false
	fog.reset_fog()
	_sync_tokens()


func _demo_cmd_move(t: Vector2i) -> AgentCommand:
	var c := AgentCommand.new()
	c.command_type = AgentCommand.CommandType.MOVE_TO_CELL
	c.target_cell = t
	return c


func _demo_cmd_stance(s: StringName) -> AgentCommand:
	var c := AgentCommand.new()
	c.command_type = AgentCommand.CommandType.SET_STANCE
	c.stance_name = s
	return c


func _demo_cmd_wait(g: StringName) -> AgentCommand:
	var c := AgentCommand.new()
	c.command_type = AgentCommand.CommandType.WAIT_GO_CODE
	c.go_code = g
	return c


func _demo_cmd_breach(t: Vector2i) -> AgentCommand:
	var c := AgentCommand.new()
	c.command_type = AgentCommand.CommandType.PERFORM_ACTION
	c.target_cell = t
	c.action_kind = AgentCommand.ActionKind.BREACH_CHARGE
	return c


func _demo_plan_op0() -> Array[AgentCommand]:
	return [
		_demo_cmd_move(Vector2i(7, 2)),
		_demo_cmd_stance(&"cautious"),
		_demo_cmd_move(Vector2i(7, 4)),
	]


func _demo_plan_op1() -> Array[AgentCommand]:
	return [
		_demo_cmd_move(Vector2i(13, 6)),
		_demo_cmd_breach(Vector2i(8, 6)),
		_demo_cmd_wait(&"alpha"),
		_demo_cmd_move(Vector2i(2, 6)),
	]
