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

var _hud := Control.new()
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
	map = MapLoader.load_from_json("res://data/maps/op01_glass_house.json")
	if map.width_cells < 1 or map.height_cells < 1:
		map = GreyboxMap.build_default()
	_apply_theme()
	renderer = MapRenderer.new()
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
	_setup_hud()


func _on_viewport_resized() -> void:
	if camera != null:
		camera.set_viewport_size(get_viewport_rect().size)
	if _hud != null:
		_hud.position = Vector2(0, get_viewport_rect().size.y - 80)


func _physics_process(_delta: float) -> void:
	if world != null and SimClock.phase == SimClock.Phase.EXECUTION:
		world.step()
		_sync_tokens()
		_update_fog()
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
	_tm = ThemeManager.new()
	_tm.theme_changed.connect(_on_theme_changed)
	_tm.apply()
	_on_theme_changed(_tm._palette())


func _on_theme_changed(pal: Dictionary) -> void:
	if squad_hud != null:
		squad_hud.apply_palette(pal)


func _setup_hud() -> void:
	_execute_button = Button.new()
	_execute_button.text = "Execute"
	_execute_button.pressed.connect(_on_execute_pressed)
	_alpha_button = Button.new()
	_alpha_button.text = "Alpha"
	_alpha_button.pressed.connect(_on_alpha_pressed)
	_bravo_button = Button.new()
	_bravo_button.text = "Bravo"
	_bravo_button.pressed.connect(_on_bravo_pressed)
	_charlie_button = Button.new()
	_charlie_button.text = "Charlie"
	_charlie_button.pressed.connect(_on_charlie_pressed)
	_delta_button = Button.new()
	_delta_button.text = "Delta"
	_delta_button.pressed.connect(_on_delta_pressed)
	_reset_button = Button.new()
	_reset_button.text = "Reset"
	_reset_button.pressed.connect(_on_reset_pressed)
	for b in [_execute_button, _alpha_button, _bravo_button, _charlie_button, _delta_button, _reset_button]:
		_hud.add_child(b)
	_hud_canvas = CanvasLayer.new()
	_hud_canvas.add_child(_hud)
	add_child(_hud_canvas)
	squad_hud = SquadHud.new()
	_hud_canvas.add_child(squad_hud)
	squad_hud.refresh(world)
	_place_hud()


func _place_hud() -> void:
	var vp: Vector2 = get_viewport_rect().size
	_hud.size = Vector2(vp.x, 80)
	_hud.position = Vector2(0, vp.y - 80)
	var bw: float = (1080.0 - 5.0 * 16.0) / 6.0
	var gap: float = 16.0
	var x: float = 16.0
	for b in [_execute_button, _alpha_button, _bravo_button, _charlie_button, _delta_button, _reset_button]:
		b.position = Vector2(x, 8.0)
		b.size = Vector2(bw, 64.0)
		x += bw + gap


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
