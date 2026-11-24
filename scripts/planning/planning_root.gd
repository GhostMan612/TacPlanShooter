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
var overlay: TacticalOverlay = null
var prep_flow: MissionPrepFlow = null
var local_faction_id: int = 0

const OPERATIVE_COUNT := 2
const NODE_BUTTON_PX := 104
const GREYBOX_SOURCE := "greybox_default"

const ROUTE_HINT := "Hold an operative and draw a route. Tap a route cell to add a go-code wait."

var squads := SquadConfig.new()
var spawn_cells: Array[Vector2i] = []
var plans := {}
var route_cells := {}
var _route_waits := {}
var _route_orders := {}
var _node_menu: PanelContainer = null
var _node_buttons: Dictionary = {}
var _invalid_routes := {}
var _selected_op := -1
var _selected_node := RoutePlanner.NO_CELL
var _checkpoints: Array[Vector2i] = []
var _exits: Array[Vector2i] = []
var _reached_checkpoints := {}
var _result_view: AarScreen = null
var _pending_go_codes: Array[StringName] = []
var _status_label: Label = null
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
	_load_mission_targets()
	_apply_theme()
	renderer = MapRenderer.new()
	renderer.apply_palette(_tm.palette())
	renderer.setup(map)
	add_child(renderer)
	fog = FogLayer.new()
	fog.setup(map)
	fog.apply_palette(_tm.palette())
	add_child(fog)
	fog.visible = false
	overlay = TacticalOverlay.new()
	overlay.local_faction_id = local_faction_id
	overlay.z_index = 2
	overlay.apply_palette(_tm.palette())
	add_child(overlay)
	prep_flow = MissionPrepFlow.new()
	add_child(prep_flow)
	spawn_cells = spawn_cells_for(map, map_source == GREYBOX_SOURCE, OPERATIVE_COUNT)
	for i in range(spawn_cells.size()):
		var token := OperativeToken.new(i)
		token.position = GridUtil.cell_center_px(spawn_cells[i])
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
	for i in range(spawn_cells.size()):
		controller.op_colors[i] = PlanBoard.squad_color(SquadConfig.SQUADS[i % SquadConfig.SQUADS.size()])
	controller.route_committed.connect(_on_route_committed)
	controller.cell_tapped.connect(_on_route_node_tapped)
	add_child(controller)
	get_viewport().size_changed.connect(_on_viewport_resized)
	world = SimWorld.new()
	_rebuild_world()
	for i in range(spawn_cells.size()):
		squads.add_member(SquadConfig.SQUADS[i % SquadConfig.SQUADS.size()], i)
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
	map_source = GREYBOX_SOURCE
	return GreyboxMap.build_default()


func _on_viewport_resized() -> void:
	if camera != null:
		camera.set_viewport_size(get_viewport_rect().size)
	_place_hud()


func _physics_process(_delta: float) -> void:
	if world != null and SimClock.phase == SimClock.Phase.EXECUTION:
		for code in _pending_go_codes:
			world.schedule_go_code(code)
		_pending_go_codes.clear()
		var journal_start := world.journal.size()
		world.step()
		for i in range(journal_start, world.journal.size()):
			if world.journal[i]["ev"] == &"breach_opened":
				renderer.refresh()
				break
		_sync_tokens()
		_update_fog()
		if squad_hud != null:
			squad_hud.refresh(world)
		_maybe_aar()


func _sync_tokens() -> void:
	if world == null or controller == null:
		return
	for o in world.operatives:
		for token in controller.tokens:
			if token.op_id == o.id:
				token.sync_from(o, o.pos * float(SimConstants.GRID_CELL_SIZE_PX))


func _update_fog() -> void:
	if fog == null or world == null or world.map == null:
		return
	fog.visible = true
	fog.update_visibility(world, local_faction_id)
	overlay.update_contacts(world, fog.live_polygons_cells())


func _apply_theme() -> void:
	_tm = ThemeManager.apply_saved()
	_tm.theme_changed.connect(_on_theme_changed)


func _on_theme_changed(pal: Dictionary) -> void:
	if renderer != null:
		renderer.apply_palette(pal)
	if fog != null:
		fog.apply_palette(pal)
	if overlay != null:
		overlay.apply_palette(pal)
	if squad_hud != null:
		squad_hud.apply_palette(pal)
		_configure_tokens(pal)


func _configure_tokens(pal: Dictionary) -> void:
	for token in controller.tokens:
		var squad := squad_hud.squad_of(token.op_id)
		token.configure(PlanBoard.squad_color(squad), squad_hud.callsign(token.op_id), pal["ink"])


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
	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.text = _planning_hint()
	_hud_canvas.add_child(_status_label)
	_build_node_menu(settings)
	_set_phase_controls(false)
	squad_hud = SquadHud.new()
	squad_hud.squads = squads
	squad_hud.operative_selected.connect(_on_operative_selected)
	_hud_canvas.add_child(squad_hud)
	squad_hud.apply_palette(_tm.palette())
	squad_hud.refresh(world)
	for c in [_menu_button, _hud, squad_hud, _status_label, _node_menu]:
		(c as Control).theme = _tm.applied_theme
	_configure_tokens(_tm.palette())
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
	if _status_label != null:
		_status_label.position = Vector2(margin * 2.0 + 280.0, 72.0)
		_status_label.size = Vector2(vp.x - margin * 3.0 - 280.0, bar_h)
	if squad_hud != null:
		squad_hud.place(Rect2(Vector2(margin, vp.y - bar_h - margin * 2.0 - SquadHud.HEIGHT_PX), Vector2(vp.x - margin * 2.0, SquadHud.HEIGHT_PX)))
	if _node_menu != null:
		_node_menu.position = Vector2(margin, 72.0 + bar_h + margin)
		_node_menu.size = Vector2(vp.x - margin * 2.0, 0.0)


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
	if world == null or _result_view != null or SimClock.phase != SimClock.Phase.PLANNING:
		return
	if not _invalid_routes.is_empty():
		_set_status("Redraw the blocked routes before executing.")
		return
	var routed := 0
	for cells in route_cells.values():
		if not cells.is_empty():
			routed += 1
	if routed == 0:
		_set_status(_planning_hint())
		return
	_pending_go_codes.clear()
	SimClock.start_execution()
	_set_phase_controls(true)
	_set_status("EXECUTING · %d of %d operatives routed" % [routed, spawn_cells.size()])


func _select_go_code(code: StringName) -> void:
	if world == null or _result_view != null:
		return
	if SimClock.phase == SimClock.Phase.EXECUTION:
		if not _pending_go_codes.has(code):
			_pending_go_codes.append(code)
		_set_status("GO-CODE " + String(code).to_upper() + " sent")
	elif _selected_node != RoutePlanner.NO_CELL:
		var waits: Dictionary = _route_waits.get(_selected_op, {})
		if waits.get(_selected_node, &"") == code:
			waits.erase(_selected_node)
		else:
			waits[_selected_node] = code
		_route_waits[_selected_op] = waits
		_compile_route(_selected_op)
		_rebuild_world()
		_show_selected_node()


func _on_alpha_pressed() -> void:
	_select_go_code(&"alpha")


func _on_bravo_pressed() -> void:
	_select_go_code(&"bravo")


func _on_charlie_pressed() -> void:
	_select_go_code(&"charlie")


func _on_delta_pressed() -> void:
	_select_go_code(&"delta")


func _on_reset_pressed() -> void:
	if world == null:
		return
	if _result_view != null:
		_hud_canvas.remove_child(_result_view)
		_result_view.queue_free()
		_result_view = null
	_pending_go_codes.clear()
	_selected_node = RoutePlanner.NO_CELL
	SimClock.reset_to_planning()
	_rebuild_world()
	_set_phase_controls(false)
	fog.reset_fog()
	fog.visible = false
	overlay.reset()
	_set_status(_planning_hint() if plans.is_empty() else "RESET · Routes kept. " + _planning_hint())


func _on_route_committed(op_id: int, waypoints: Array[Vector2i]) -> void:
	if SimClock.phase != SimClock.Phase.PLANNING or op_id < 0 or op_id >= spawn_cells.size():
		return
	var start: Vector2i = spawn_cells[op_id]
	var result := RoutePlanner.plan(map, start, waypoints)
	var cells: Array[Vector2i] = result["cells"]
	var blocked: Vector2i = result["blocked_at"]
	plans[op_id] = result["commands"]
	route_cells[op_id] = cells
	_route_waits.erase(op_id)
	_route_orders.erase(op_id)
	_selected_node = RoutePlanner.NO_CELL
	squad_hud.touch_operative(op_id)
	controller.show_route(op_id, RoutePlanner.path_points_px(start, cells))
	controller.show_waits(op_id, {})
	if blocked != RoutePlanner.NO_CELL:
		_invalid_routes[op_id] = blocked
	else:
		_invalid_routes.erase(op_id)
	_rebuild_world()
	var who := squad_hud.callsign(op_id)
	if blocked != RoutePlanner.NO_CELL:
		_set_status("%s route blocked at %s. Redraw to continue." % [who, _cell_name(blocked)])
	else:
		var doors := (plans[op_id] as Array).size() - cells.size()
		var action_note := " · %d door action%s" % [doors, "" if doors == 1 else "s"] if doors > 0 else ""
		_set_status("%s route set · %d cells%s. Tap a route cell to set a wait." % [who, cells.size(), action_note])


func _on_operative_selected(op_id: int) -> void:
	_selected_op = op_id
	_selected_node = RoutePlanner.NO_CELL
	for token in controller.tokens:
		token.set_selected(token.op_id == op_id)
	if SimClock.phase == SimClock.Phase.PLANNING:
		_set_phase_controls(false)


func _on_route_node_tapped(cell: Vector2i) -> void:
	if SimClock.phase != SimClock.Phase.PLANNING or _result_view != null:
		return
	_selected_node = RoutePlanner.NO_CELL
	if _has_route_node(_selected_op, cell):
		_selected_node = cell
	else:
		for op_id in range(spawn_cells.size()):
			if _has_route_node(op_id, cell):
				squad_hud.touch_operative(op_id)
				_selected_node = cell
				break
	_set_phase_controls(false)
	if _selected_node != RoutePlanner.NO_CELL:
		_show_selected_node()


func _has_route_node(op_id: int, cell: Vector2i) -> bool:
	if not route_cells.has(op_id):
		return false
	var cells: Array[Vector2i] = route_cells[op_id]
	return not cells.is_empty() and (cell == spawn_cells[op_id] or cells.has(cell))


func _show_selected_node() -> void:
	var summary := node_summary(_selected_op, _selected_node)
	var detail := "Set orders below or a WAIT code." if summary.is_empty() else summary
	_set_status("%s · %s · %s" % [squad_hud.callsign(_selected_op), _cell_name(_selected_node), detail])
	_refresh_node_menu()


func node_order(op_id: int, cell: Vector2i) -> Dictionary:
	var orders: Dictionary = _route_orders.get(op_id, {})
	return orders.get(cell, {})


func node_summary(op_id: int, cell: Vector2i) -> String:
	var parts := PackedStringArray()
	var order := node_order(op_id, cell)
	if order.has("stance"):
		parts.append(String(order["stance"]).to_upper())
	if order.has("mode"):
		parts.append(String(order["mode"]).to_upper())
	if order.has("fof"):
		parts.append(_facing_label(int(order["fof"])))
	var waits: Dictionary = _route_waits.get(op_id, {})
	if waits.has(cell):
		parts.append("WAIT " + String(waits[cell]).to_upper())
	if order.has("action"):
		parts.append(_action_label(int(order["action"])))
	return " · ".join(parts)


static func _facing_label(bearing: int) -> String:
	match bearing:
		-1:
			return "FACE FREE"
		0:
			return "FACE E"
		90:
			return "FACE S"
		180:
			return "FACE W"
		270:
			return "FACE N"
	return "FACE %d" % bearing


static func _action_label(kind: int) -> String:
	match kind:
		AgentCommand.ActionKind.FLASHBANG:
			return "FLASHBANG"
		AgentCommand.ActionKind.FRAG:
			return "FRAG"
		AgentCommand.ActionKind.TEAR_GAS:
			return "GAS"
	return "ACTION"


func _build_node_menu(settings: Dictionary) -> void:
	_node_menu = PanelContainer.new()
	_node_menu.name = "NodeMenu"
	_node_menu.visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_node_menu.add_child(col)
	var rows := [
		["STANCE", "stance", [["CAUTIOUS", &"cautious"], ["NORMAL", &"normal"], ["BLITZ", &"blitz"]]],
		["MODE", "mode", [["ENGAGE", &"engage"], ["ADVANCE", &"advance"], ["ESCORT", &"escort"]]],
		["ACTION", "action", [["FLASH", AgentCommand.ActionKind.FLASHBANG], ["FRAG", AgentCommand.ActionKind.FRAG], ["GAS", AgentCommand.ActionKind.TEAR_GAS]]],
		["FACE", "fof", [["N", 270], ["E", 0], ["S", 90], ["W", 180], ["FREE", -1]]],
	]
	for row in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		var title := Label.new()
		title.text = String(row[0])
		title.custom_minimum_size = Vector2(170, 0)
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(title)
		for opt in row[2]:
			var b := UiKit.button(String(opt[0]), _set_node_order.bind(String(row[1]), opt[1]), settings)
			b.toggle_mode = true
			b.custom_minimum_size = Vector2(0, NODE_BUTTON_PX)
			b.name = "Node_%s_%s" % [String(row[1]), String(opt[0])]
			_node_buttons[b.name] = [String(row[1]), opt[1], b]
			line.add_child(b)
		col.add_child(line)
	var clear_btn := UiKit.button("CLEAR NODE", _clear_node, settings)
	clear_btn.name = "Node_clear"
	clear_btn.custom_minimum_size = Vector2(0, NODE_BUTTON_PX)
	col.add_child(clear_btn)
	_hud_canvas.add_child(_node_menu)


func _set_node_order(key: String, value: Variant) -> void:
	if SimClock.phase != SimClock.Phase.PLANNING or _result_view != null or _selected_node == RoutePlanner.NO_CELL:
		return
	var orders: Dictionary = _route_orders.get(_selected_op, {})
	var order: Dictionary = orders.get(_selected_node, {})
	if order.has(key) and order[key] == value:
		order.erase(key)
	else:
		order[key] = value
	if order.is_empty():
		orders.erase(_selected_node)
	else:
		orders[_selected_node] = order
	_route_orders[_selected_op] = orders
	_compile_route(_selected_op)
	_rebuild_world()
	_show_selected_node()


func _clear_node() -> void:
	if SimClock.phase != SimClock.Phase.PLANNING or _selected_node == RoutePlanner.NO_CELL:
		return
	var orders: Dictionary = _route_orders.get(_selected_op, {})
	orders.erase(_selected_node)
	_route_orders[_selected_op] = orders
	var waits: Dictionary = _route_waits.get(_selected_op, {})
	waits.erase(_selected_node)
	_route_waits[_selected_op] = waits
	_compile_route(_selected_op)
	_rebuild_world()
	_show_selected_node()


func _refresh_node_menu() -> void:
	if _node_menu == null:
		return
	var menu_open := SimClock.phase == SimClock.Phase.PLANNING and _result_view == null and _selected_node != RoutePlanner.NO_CELL
	_node_menu.visible = menu_open
	if not menu_open:
		return
	var order := node_order(_selected_op, _selected_node)
	for key in _node_buttons:
		var entry: Array = _node_buttons[key]
		var b: Button = entry[2]
		b.set_pressed_no_signal(order.has(String(entry[0])) and order[String(entry[0])] == entry[1])


func _compile_route(op_id: int) -> void:
	var cells: Array[Vector2i] = route_cells[op_id]
	var waits: Dictionary = _route_waits.get(op_id, {})
	var orders: Dictionary = _route_orders.get(op_id, {})
	plans[op_id] = RoutePlanner.compile_commands(map, spawn_cells[op_id], cells, waits, orders)
	var marks := {}
	for cell in waits:
		marks[cell] = String(waits[cell]).substr(0, 1).to_upper()
	for cell in orders:
		marks[cell] = String(marks.get(cell, "")) + "*"
	controller.show_waits(op_id, marks)


static func _cell_name(cell: Vector2i) -> String:
	return "%s%02d" % [MapRenderer.col_letter(cell.x), cell.y + 1]


func _rebuild_world() -> void:
	world.setup(map, DEV_SEED)
	_reached_checkpoints.clear()
	renderer.setup(world.map)
	_populate_world()
	_sync_tokens()
	if squad_hud != null:
		squad_hud.refresh(world)


func _set_phase_controls(executing: bool) -> void:
	var result_visible := _result_view != null
	if _execute_button != null:
		_execute_button.disabled = executing or result_visible
	var code_buttons := [_alpha_button, _bravo_button, _charlie_button, _delta_button]
	for i in range(code_buttons.size()):
		var b: Button = code_buttons[i]
		if b != null:
			b.disabled = result_visible or (not executing and _selected_node == RoutePlanner.NO_CELL)
			b.text = ("SEND " if executing else "WAIT ") + "ABCD".substr(i, 1)
	if controller != null:
		controller.routing_enabled = not executing and not result_visible
	_refresh_node_menu()


func _set_status(msg: String) -> void:
	if _status_label != null:
		_status_label.text = msg


func _load_mission_targets() -> void:
	for objective in map.objectives:
		var cell := MapEditorValidator.cell_of(objective.get("cell", []))
		if map.in_bounds(cell) and not _checkpoints.has(cell):
			_checkpoints.append(cell)
	for zone in map.extraction_zones:
		for entry in zone.get("cells", []):
			var cell := MapEditorValidator.cell_of(entry)
			if map.in_bounds(cell) and not _exits.has(cell):
				_exits.append(cell)


func _planning_hint() -> String:
	if _checkpoints.is_empty() and _exits.is_empty():
		return "Ground-floor practice. " + ROUTE_HINT
	var goal := "Reach the marked checkpoints. " if not _checkpoints.is_empty() else ""
	if not _exits.is_empty():
		goal += "Finish a route at an amber exit. "
	return goal + ROUTE_HINT


func _maybe_aar() -> void:
	var alive := 0
	var all_finished := true
	var halted := false
	var at_exit := false
	for op in world.operatives:
		if not op.is_alive():
			continue
		alive += 1
		all_finished = all_finished and (op.done or op.halted)
		halted = halted or op.halted
		var cell := GridUtil.cell_of(op.pos)
		if _checkpoints.has(cell):
			_reached_checkpoints[cell] = true
		at_exit = at_exit or (op.done and _exits.has(cell))
	if alive == 0:
		_show_result(false, "No operatives remaining.", alive)
	elif all_finished and world.pending.is_empty() and world.entities.is_empty():
		var complete := not halted and _reached_checkpoints.size() == _checkpoints.size() and (_exits.is_empty() or at_exit)
		var reason := "All routes completed."
		if halted:
			reason = "An operative halted before completing the plan."
		elif _reached_checkpoints.size() != _checkpoints.size():
			reason = "One or more checkpoints were missed."
		elif not _exits.is_empty() and not at_exit:
			reason = "No operative finished at an exit."
		_show_result(complete, reason, alive)


func _show_result(complete: bool, reason: String, alive: int) -> void:
	_result_view = AarScreen.new()
	_result_view.name = "OperationResult"
	_result_view.result = {
		"completed": complete,
		"practice": _checkpoints.is_empty() and _exits.is_empty(),
		"reason": reason,
		"reached": _reached_checkpoints.size(),
		"checkpoints": _checkpoints.size(),
		"alive": alive,
		"operatives": world.operatives.size(),
		"ticks": world.tick,
	}
	_result_view.retry_requested.connect(_on_reset_pressed)
	_result_view.leave_requested.connect(_go_back)
	_hud_canvas.add_child(_result_view)
	SimClock.reset_to_planning()
	_set_phase_controls(false)


func _populate_world() -> void:
	for i in range(spawn_cells.size()):
		var plan: Array[AgentCommand] = []
		if plans.has(i):
			for cmd in plans[i]:
				plan.append(cmd)
		world.add_operative(i, spawn_cells[i], plan)
	for i in range(map.ai_spawns.size()):
		var entry: Dictionary = map.ai_spawns[i]
		var cell := MapEditorValidator.cell_of(entry.get("cell", []))
		if map.in_bounds(cell) and not map.is_solid(cell):
			world.add_enemy(OPERATIVE_COUNT + i, cell, StringName(String(entry.get("archetype", ""))), float(entry.get("facing_deg", 0.0)))


static func spawn_cells_for(m: GreyboxMap, greybox: bool, count: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if greybox:
		out.append(Vector2i(2, 2))
		out.append(Vector2i(13, 2))
		return out
	for z in m.insertion_zones:
		for c in z.get("cells", []):
			var cell := MapEditorValidator.cell_of(c)
			if out.size() < count and m.in_bounds(cell) and not m.is_solid(cell) and not out.has(cell):
				out.append(cell)
	if out.is_empty():
		for y in range(m.height_cells):
			for x in range(m.width_cells):
				if out.is_empty() and not m.is_solid(Vector2i(x, y)):
					out.append(Vector2i(x, y))
	if out.is_empty():
		return out
	var queue: Array[Vector2i] = [out[0]]
	var seen := {out[0]: true}
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	while out.size() < count and not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in dirs:
			var n: Vector2i = cur + d
			if m.in_bounds(n) and not m.is_solid(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
				if out.size() < count and not out.has(n):
					out.append(n)
	return out
