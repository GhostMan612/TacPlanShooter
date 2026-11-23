# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name PlanningRoot
extends Node2D

const DEV_SEED := 1337

var map: GreyboxMap = null
var renderer: MapRenderer = null
var camera: MissionCamera = null
var controller: PlanningController = null
var world: SimWorld = null

var _hud := Control.new()
var _execute_button: Button = null
var _go_code_button: Button = null
var _reset_button: Button = null


func _ready() -> void:
	var phase_name := "PLANNING" if SimClock.phase == SimClock.Phase.PLANNING else "EXECUTION"
	var method: String = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	print("[TacPlan] boot OK phase=%s fps_cap=%d renderer=%s ticks_per_sec=%d" % [
		phase_name,
		Engine.max_fps,
		method,
		Engine.physics_ticks_per_second,
	])
	map = GreyboxMap.build_default()
	renderer = MapRenderer.new()
	renderer.setup(map)
	add_child(renderer)
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


func _sync_tokens() -> void:
	if world == null or controller == null:
		return
	for o in world.operatives:
		for token in controller.tokens:
			if token.op_id == o.id:
				token.position = GridUtil.cell_center_px(GridUtil.cell_of(o.pos))


func _setup_hud() -> void:
	_execute_button = Button.new()
	_execute_button.text = "Execute"
	_execute_button.pressed.connect(_on_execute_pressed)
	_go_code_button = Button.new()
	_go_code_button.text = "Go-Code: Alpha"
	_go_code_button.pressed.connect(_on_go_code_pressed)
	_reset_button = Button.new()
	_reset_button.text = "Reset"
	_reset_button.pressed.connect(_on_reset_pressed)
	_hud.add_child(_execute_button)
	_hud.add_child(_go_code_button)
	_hud.add_child(_reset_button)
	add_child(_hud)
	_place_hud()


func _place_hud() -> void:
	var vp: Vector2 = get_viewport_rect().size
	_hud.size = Vector2(vp.x, 80)
	_hud.position = Vector2(0, vp.y - 80)
	var bw: float = 200.0
	var gap: float = 16.0
	var x: float = 16.0
	for b in [_execute_button, _go_code_button, _reset_button]:
		b.position = Vector2(x, 8.0)
		b.size = Vector2(bw, 64.0)
		x += bw + gap


func _on_execute_pressed() -> void:
	if world == null or SimClock.phase != SimClock.Phase.PLANNING:
		return
	SimClock.start_execution()
	_execute_button.disabled = true


func _on_go_code_pressed() -> void:
	if world != null:
		world.issue_go_code(&"alpha")
		print("[TacPlan] go_code issued: alpha")


func _on_reset_pressed() -> void:
	if world == null:
		return
	world.setup(map, DEV_SEED)
	world.add_operative(0, Vector2i(2, 2), _demo_plan_op0())
	world.add_operative(1, Vector2i(13, 2), _demo_plan_op1())
	SimClock.reset_to_planning()
	_execute_button.disabled = false
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
