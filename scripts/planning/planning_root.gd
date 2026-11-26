# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name PlanningRoot
extends Node2D

const DEV_SEED := 1337

var map: GreyboxMap = null
var renderer: MapRenderer = null
var props: PropsPlacement = null
var squad_hud: SquadHud = null
var _tm: ThemeManager = null
var radial_menu: RadialMenu = null
var loupe: PipLoupe = null
var prop_layer: PropLayer = null
var camera: MissionCamera = null
var controller: PlanningController = null
var world: SimWorld = null
var fog: FogLayer = null
var overlay: TacticalOverlay = null
var vfx: TacticalVfx = null
var prep_flow: MissionPrepFlow = null
var tap_in: TapInController = null
var lockstep: LockstepSession = null
var local_faction_id: int = 0
var mission_loadout: Array = []
var two_player_config: Dictionary = {}
var _pass_play_stage: int = 0
var _p1_plan_json: String = ""
var _p1_salt: String = "tacplan_p1"
var _p1_commitment: String = ""
var _consumed_enemy_spawns: int = 0
var _initial_snapshot: MissionSnapshot = null
var _recorded_go_codes: Array[Dictionary] = []
var _recorded_overrides: Array[OverrideCommand] = []
var _recorded_max_tick: int = 0

const OPERATIVE_COUNT := 2
const NODE_BUTTON_PX := 56
const GREYBOX_SOURCE := "greybox_default"

const ROUTE_HINT := "Hold unit & draw, or switch to TAP mode."

var squads := SquadConfig.new()
var spawn_cells: Array[Vector2i] = []
var plans := {}
var route_cells := {}
var _floor_segments := {}
var _route_waits := {}
var _route_orders := {}
var _node_menu: PanelContainer = null
var _node_buttons: Dictionary = {}
var _invalid_routes := {}
var _selected_op := -1
var _selected_node := RoutePlanner.NO_CELL
var _active_floor := 0
var _checkpoints: Array[Vector3i] = []
var _exits: Array[Vector3i] = []
var _reached_checkpoints := {}
var _result_view: AarScreen = null
var _pending_go_codes: Array[StringName] = []
var _status_label: Label = null
var map_source := ""
var _hud: HBoxContainer = null
var _menu_button: Button = null
var _mode_button: Button = null
var _floor_button: Button = null
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
	renderer.enable_hd_tiles()
	prop_layer = PropLayer.new()
	prop_layer.setup(map)
	add_child(prop_layer)
	y_sort_enabled = true
	add_child(renderer)
	props = PropsPlacement.new()
	props.z_index = 1
	props.setup(map)
	add_child(props)
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
	vfx = TacticalVfx.new()
	vfx.z_index = 3
	add_child(vfx)
	prep_flow = MissionPrepFlow.new()
	add_child(prep_flow)
	tap_in = TapInController.new()
	add_child(tap_in)
	lockstep = LockstepSession.new()
	add_child(lockstep)
	tap_in.lockstep = lockstep
	_load_session_configs()
	spawn_cells = _resolve_spawn_cells()
	for i in range(spawn_cells.size()):
		var token := OperativeToken.new(i)
		token.position = GridUtil.cell_center_px(spawn_cells[i])
		token.z_index = 1
		add_child(token)
	camera = MissionCamera.new()
	add_child(camera)
	var map_px := Vector2(map.width_cells, map.height_cells) * float(SimConstants.GRID_CELL_SIZE_PX)
	camera.configure_for_map(map_px, get_viewport_rect().size)
	camera.apply_uniform_zoom(camera.zoom.x * 0.86)
	_center_camera_if_short(map_px)
	camera.make_current()
	controller = PlanningController.new()
	controller.camera = camera
	controller.map = map
	controller.line_container = self
	for child in get_children():
		if child is OperativeToken:
			controller.tokens.append(child as OperativeToken)
	for i in range(spawn_cells.size()):
		controller.op_colors[i] = PlanBoard.squad_color(_assigned_squad_for(i))
	controller.route_committed.connect(_on_route_committed)
	controller.cell_tapped.connect(_on_route_node_tapped)
	controller.execution_cell_tapped.connect(_on_execution_cell_tapped)
	add_child(controller)
	get_viewport().size_changed.connect(_on_viewport_resized)
	world = SimWorld.new()
	_rebuild_world()
	for i in range(spawn_cells.size()):
		squads.add_member(_assigned_squad_for(i), i)
	_setup_hud()
	_apply_turn_controllability()
	_set_phase_controls(false)
	print("[TacPlan] planning map=%s size=%dx%d floors=%d" % [map_source, map.width_cells, map.height_cells, map.floor_count])


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


func _follow_execution_camera() -> void:
	if camera == null or world == null:
		return
	var active: SimOperative = null
	for o in world.operatives:
		if o.faction_id == local_faction_id and o.is_alive():
			active = o
			break
	if active == null:
		return
	var density := clampf(float(world.operatives.size()) / 6.0, 0.0, 1.0)
	camera.follow_world(GridUtil.cell_center_px(GridUtil.cell_of(active.pos)), density)


func _on_viewport_resized() -> void:
	if camera != null:
		camera.set_viewport_size(get_viewport_rect().size)
		if map != null:
			_center_camera_if_short(Vector2(map.width_cells, map.height_cells) * float(SimConstants.GRID_CELL_SIZE_PX))
	_place_hud()


func _physics_process(_delta: float) -> void:
	if lockstep != null and lockstep.session_active:
		lockstep.poll()
		_consume_lan_packets()
	if radial_menu != null and Input.is_action_just_pressed(&"ui_right"):
		radial_menu.open_at(Vector2(get_viewport_rect().size.x / 2.0, get_viewport_rect().size.y / 2.0))
	if world != null and SimClock.phase == SimClock.Phase.EXECUTION:
		_follow_execution_camera()
		if lockstep != null and lockstep.session_active:
			lockstep.process_tick(world)
		for code in _pending_go_codes:
			world.schedule_go_code(code)
		_pending_go_codes.clear()
		var journal_start := world.journal.size()
		world.step()
		_emit_audio_events(journal_start)
		for i in range(journal_start, world.journal.size()):
			if world.journal[i]["ev"] == &"breach_opened":
				renderer.refresh()
				break
		_sync_tokens()
		_update_fog()
		if squad_hud != null:
			squad_hud.refresh(world)
		_maybe_aar()


func _emit_audio_events(from_idx: int) -> void:
	var eb := get_node_or_null("/root/EventBus")
	if world == null:
		return
	for i in range(from_idx, world.journal.size()):
		var e: Dictionary = world.journal[i]
		var ev := StringName(String(e.get("ev", "")))
		if ev == &"breach_opened":
			var bcell := Vector2i(int(e.get("cx", 0)), int(e.get("cy", 0)))
			var bpos := GridUtil.cell_center_px(bcell)
			if eb != null:
				eb.breach_detonated.emit(bpos)
			if vfx != null and int(e.get("floor", 0)) == _active_floor:
				vfx.spawn_breach_shockwave(bpos)
		elif ev == &"go_issued":
			if eb != null:
				eb.go_code_issued.emit(StringName(String(e.get("code", ""))))
		elif ev == &"stairs_used" and int(e.get("op", -1)) == 0:
			var s_floor := int(e.get("floor", 0))
			if s_floor != _active_floor:
				_set_active_floor(s_floor)
		elif ev == &"shot":
			var shooter := _find_actor(int(e.get("op", -1)))
			var target := _find_actor(int(e.get("target", -1)))
			if vfx != null and shooter != null and target != null and shooter.floor_idx == _active_floor:
				var spos := shooter.pos * float(SimConstants.GRID_CELL_SIZE_PX)
				var tpos := target.pos * float(SimConstants.GRID_CELL_SIZE_PX)
				vfx.spawn_muzzle_flash(spos)
				vfx.spawn_bullet_tracer(spos, tpos)
			if bool(e.get("hit", false)):
				var tid := int(e.get("target", -1))
				for op in world.operatives:
					if op.id == tid and eb != null:
						eb.operative_damaged.emit(op.id, op.hp)
						break
		elif ev == &"entity_effect" and vfx != null and int(e.get("floor", 0)) == _active_floor:
			var ep := GridUtil.cell_center_px(Vector2i(int(e.get("tx", 0)), int(e.get("ty", 0))))
			var kind := int(e.get("kind", 0))
			if kind == int(AgentCommand.ActionKind.FLASHBANG):
				vfx.spawn_flashbang_bloom(ep)
				vfx.spawn_stun_ring(ep)
			elif kind == int(AgentCommand.ActionKind.TEAR_GAS):
				vfx.spawn_tear_gas_cloud(ep)
			elif kind == int(AgentCommand.ActionKind.FRAG):
				vfx.spawn_breach_shockwave(ep)


func _find_actor(id: int) -> SimOperative:
	if world == null:
		return null
	for o in world.operatives:
		if o.id == id:
			return o
	return world.enemy_actors.get(id, null)


func _sync_tokens() -> void:
	if world == null or controller == null:
		return
	for token in controller.tokens:
		if SimClock.phase == SimClock.Phase.PLANNING and _result_view == null:
			var seg_floor := _planning_floor_for_op(token.op_id)
			var seg_pos := _planning_cell_for_op(token.op_id, seg_floor)
			token.visible = seg_floor == _active_floor
			token.position = GridUtil.cell_center_px(seg_pos)
			continue
		for o in world.operatives:
			if token.op_id == o.id:
				token.visible = o.floor_idx == _active_floor
				token.sync_from(o, o.pos * float(SimConstants.GRID_CELL_SIZE_PX))


func _update_fog() -> void:
	if fog == null or world == null or world.map == null:
		return
	fog.visible = true
	fog.update_visibility(world, local_faction_id, _active_floor)
	overlay.update_contacts(world, fog.live_polygons_cells(), _active_floor)


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
	var sprite_paths: Array[String] = ["res://assets/sprites/op_pointman.png", "res://assets/sprites/op_breacher.png"]
	for token in controller.tokens:
		var squad := squad_hud.squad_of(token.op_id)
		token.configure(PlanBoard.squad_color(squad), squad_hud.callsign(token.op_id), pal["ink"])
		var sp: String = sprite_paths[token.op_id % sprite_paths.size()]
		if ResourceLoader.exists(sp):
			var tex := ResourceLoader.load(sp, "Texture2D") as Texture2D
			if tex != null:
				token.set_sprite(tex)


func _setup_hud() -> void:
	var settings := ThemeManager.load_settings()
	_hud_canvas = CanvasLayer.new()
	add_child(_hud_canvas)
	loupe = PipLoupe.new()
	_hud_canvas.add_child(loupe)
	if controller != null:
		controller.loupe = loupe
	radial_menu = RadialMenu.new()
	radial_menu.go_code_selected.connect(_on_radial_go_code)
	_hud_canvas.add_child(radial_menu)
	_menu_button = UiKit.button("< MENU", _go_back, settings)
	_menu_button.size_flags_horizontal = Control.SIZE_FILL
	_menu_button.add_theme_font_size_override("font_size", 24)
	_hud_canvas.add_child(_menu_button)
	_mode_button = UiKit.button("DRAW", _toggle_input_mode, settings)
	_mode_button.size_flags_horizontal = Control.SIZE_FILL
	_mode_button.add_theme_font_size_override("font_size", 24)
	_hud_canvas.add_child(_mode_button)
	_floor_button = UiKit.button("F1/%d" % map.floor_count, _cycle_floor, settings)
	_floor_button.size_flags_horizontal = Control.SIZE_FILL
	_floor_button.add_theme_font_size_override("font_size", 24)
	_floor_button.visible = map.floor_count > 1
	_hud_canvas.add_child(_floor_button)
	_hud = HBoxContainer.new()
	_hud.name = "ActionBar"
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_theme_constant_override("separation", 8)
	_hud_canvas.add_child(_hud)
	_execute_button = UiKit.button("EXECUTE", _on_execute_pressed, settings)
	_alpha_button = UiKit.button("ALPHA", _on_alpha_pressed, settings)
	_bravo_button = UiKit.button("BRAVO", _on_bravo_pressed, settings)
	_charlie_button = UiKit.button("CHARLIE", _on_charlie_pressed, settings)
	_delta_button = UiKit.button("DELTA", _on_delta_pressed, settings)
	_reset_button = UiKit.button("RESET", _on_reset_pressed, settings)
	_execute_button.size_flags_stretch_ratio = 2.4
	_reset_button.size_flags_stretch_ratio = 1.35
	for b in [_execute_button, _alpha_button, _bravo_button, _charlie_button, _delta_button, _reset_button]:
		b.add_theme_font_size_override("font_size", 24)
		b.clip_text = true
		_hud.add_child(b)
	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.add_theme_font_size_override("font_size", 20)
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
	for c in [_menu_button, _mode_button, _floor_button, _hud, squad_hud, _status_label, _node_menu]:
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
	var row_w := vp.x - margin * 2.0
	var multi := _floor_button != null and _floor_button.visible
	var btn_w := (row_w - (24.0 if multi else 12.0)) / (3.0 if multi else 2.0)
	var cur_x := margin
	if _menu_button != null:
		_menu_button.position = Vector2(cur_x, 64.0)
		_menu_button.size = Vector2(btn_w, bar_h)
		cur_x += btn_w + 12.0
	if _mode_button != null:
		_mode_button.position = Vector2(cur_x, 64.0)
		_mode_button.size = Vector2(btn_w, bar_h)
		cur_x += btn_w + 12.0
	if multi:
		_floor_button.position = Vector2(cur_x, 64.0)
		_floor_button.size = Vector2(btn_w, bar_h)
	var status_y := 64.0 + bar_h + 8.0
	if _status_label != null:
		_status_label.position = Vector2(margin, status_y)
		_status_label.size = Vector2(row_w, 54.0)
	if squad_hud != null:
		squad_hud.place(Rect2(Vector2(margin, vp.y - bar_h - margin * 2.0 - SquadHud.HEIGHT_PX), Vector2(row_w, SquadHud.HEIGHT_PX)))
	if _node_menu != null:
		_node_menu.position = Vector2(margin, status_y + 58.0)
		_node_menu.size = Vector2(row_w, 0.0)


func _toggle_input_mode() -> void:
	if SimClock.phase == SimClock.Phase.EXECUTION:
		if world != null and tap_in != null:
			var rel_id := tap_in.op_id if tap_in.op_id >= 0 else _selected_op
			if rel_id >= 0:
				world.release_tapin(rel_id)
			tap_in.release_ai()
			_set_status("AI plan control restored.")
		return
	if controller == null:
		return
	controller.tap_to_cell_mode = not controller.tap_to_cell_mode
	if _mode_button != null:
		_mode_button.text = "TAP" if controller.tap_to_cell_mode else "DRAW"
	if _selected_op < 0:
		_selected_op = 0
		if squad_hud != null:
			squad_hud.touch_operative(0)
	_set_status("TAP mode: tap a cell to path there." if controller.tap_to_cell_mode else _planning_hint())


func _cycle_floor() -> void:
	if map == null or map.floor_count <= 1:
		return
	_set_active_floor((_active_floor + 1) % map.floor_count)


func _set_active_floor(fl: int) -> void:
	if map == null:
		return
	_active_floor = clampi(fl, 0, maxi(map.floor_count - 1, 0))
	_selected_node = RoutePlanner.NO_CELL
	if controller != null:
		controller.active_floor = _active_floor
		controller.map = world.map_on_floor(_active_floor) if world != null else map.slice_map(_active_floor)
	if _floor_button != null:
		_floor_button.text = "F%d/%d" % [_active_floor + 1, map.floor_count]
	_refresh_floor_visuals()
	if SimClock.phase == SimClock.Phase.PLANNING:
		_set_phase_controls(false)
	else:
		_update_fog()


func _refresh_floor_visuals() -> void:
	if world == null:
		return
	if renderer != null:
		renderer.setup(world.map_on_floor(_active_floor))
	if props != null:
		props.map = world.map_on_floor(_active_floor)
		props.rebuild()
	if controller != null:
		for i in range(spawn_cells.size()):
			if _floor_segments.has(i):
				var seg := _find_segment_on_floor(i, _active_floor)
				if seg.is_empty():
					controller.show_route(i, PackedVector2Array())
					controller.show_waits(i, {})
				else:
					controller.show_route(i, RoutePlanner.path_points_px(seg["start"], _current_leg_cells(i, _active_floor)))
					controller.show_waits(i, _marks_on_floor(i, _active_floor))
			elif _active_floor == 0 and route_cells.has(i):
				controller.show_route(i, RoutePlanner.path_points_px(spawn_cells[i], _current_leg_cells(i, 0)))
				controller.show_waits(i, _marks_on_floor(i, 0))
			else:
				controller.show_route(i, PackedVector2Array())
				controller.show_waits(i, {})
	_sync_tokens()
	if vfx != null:
		vfx.clear()


func _center_camera_if_short(map_px: Vector2) -> void:
	if camera == null:
		return
	var vp_sz: Vector2 = get_viewport_rect().size
	var world_h: float = vp_sz.y / maxf(camera.zoom.x, 0.01)
	if map_px.y + 96.0 < world_h:
		var pad_y: int = int(ceil((world_h - map_px.y) * 0.5)) + 64
		camera.limit_left = -72
		camera.limit_right = int(map_px.x) + 72
		camera.limit_top = -pad_y
		camera.limit_bottom = int(map_px.y) + pad_y
		camera.position = map_px * 0.5
		camera.clamp_to_limits()


func _go_back() -> void:
	if lockstep != null and lockstep.session_active:
		lockstep.close_session()
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


func _on_radial_go_code(code: StringName) -> void:
	_select_go_code(code)


func _on_execute_pressed() -> void:
	if world == null or _result_view != null or SimClock.phase != SimClock.Phase.PLANNING:
		return
	if not _invalid_routes.is_empty():
		_set_status("Redraw the blocked routes before executing.")
		return
	if _is_pass_play() and _pass_play_stage == 0:
		var p1_ops := _turn_ops(0)
		var p1_routed := 0
		for op_id in p1_ops:
			if route_cells.has(op_id) and not (route_cells[op_id] as Array).is_empty():
				p1_routed += 1
		if p1_routed == 0:
			_set_status("P1: Draw at least one route before COMMIT P1.")
			return
		_p1_plan_json = _serialize_ops_plans(p1_ops)
		var cr := CommitReveal.new()
		_p1_commitment = cr.commit(_p1_plan_json, _p1_salt)
		cr.free()
		_pass_play_stage = 1
		_apply_turn_controllability()
		_set_phase_controls(false)
		_set_status("P1 COMMIT [%s] · Hand device to P2!" % _p1_commitment.substr(0, 10))
		return
	var routed := 0
	for cells in route_cells.values():
		if not cells.is_empty():
			routed += 1
	if _is_pass_play() and _pass_play_stage == 1:
		var cr2 := CommitReveal.new()
		var valid_commit := cr2.verify(_p1_plan_json, _p1_salt, _p1_commitment)
		cr2.free()
		if not valid_commit:
			_set_status("Commit-Reveal signature mismatch.")
			return
		_reveal_all_plans_for_execution()
	elif routed == 0:
		_set_status(_planning_hint())
		return
	if lockstep != null and lockstep.session_active:
		var my_ops := _turn_ops(local_faction_id if _is_pvp() else (0 if String(two_player_config.get("role", "host")) == "host" else 1))
		lockstep.send_packet({"kind": "plan_sync", "plans": _serialize_ops_plans(my_ops)})
	_initial_snapshot = MissionSnapshot.capture(world)
	_pending_go_codes.clear()
	SimClock.start_execution()
	_set_phase_controls(true)
	_set_status("EXECUTING · Tap operative card + cell for Tap-In (-1 CP).")


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
		var rv := _result_view
		_result_view = null
		rv.visible = false
		rv.queue_free()
	_pending_go_codes.clear()
	_selected_node = RoutePlanner.NO_CELL
	_active_floor = 0
	_pass_play_stage = 0
	if tap_in != null:
		tap_in.release_ai()
	if controller != null:
		controller.active_floor = 0
		controller.map = map
	_apply_turn_controllability()
	if _floor_button != null and map != null:
		_floor_button.text = "F1/%d" % map.floor_count
	SimClock.reset_to_planning()
	_rebuild_world()
	_refresh_floor_visuals()
	_set_phase_controls(false)
	fog.reset_fog()
	fog.visible = false
	overlay.reset()
	if vfx != null:
		vfx.clear()
	_set_status(_planning_hint() if plans.is_empty() else "RESET · Routes kept. " + _planning_hint())


func _find_segment_index(segs: Array, floor_idx: int) -> int:
	for i in range(segs.size()):
		if int(segs[i].get("floor", -1)) == floor_idx:
			return i
	return -1


func _find_segment_on_floor(op_id: int, floor_idx: int) -> Dictionary:
	if not _floor_segments.has(op_id):
		return {}
	var segs: Array = _floor_segments[op_id]
	var idx := _find_segment_index(segs, floor_idx)
	return segs[idx] if idx >= 0 else {}


func _planning_cell_for_op(op_id: int, floor_idx: int) -> Vector2i:
	if _floor_segments.has(op_id):
		var seg := _find_segment_on_floor(op_id, floor_idx)
		if not seg.is_empty():
			return seg["start"]
	if op_id >= 0 and op_id < spawn_cells.size():
		return spawn_cells[op_id]
	return Vector2i.ZERO


func _planning_floor_for_op(op_id: int) -> int:
	if _floor_segments.has(op_id) and not _find_segment_on_floor(op_id, _active_floor).is_empty():
		return _active_floor
	return 0


func _marks_on_floor(op_id: int, floor_idx: int) -> Dictionary:
	var marks := {}
	var waits: Dictionary = _route_waits.get(op_id, {})
	for k in waits.keys():
		if _key_floor(k) == floor_idx:
			var c := _key_cell(k)
			marks[c] = String(waits[k]).substr(0, 1).to_upper()
	var orders: Dictionary = _route_orders.get(op_id, {})
	for k in orders.keys():
		if _key_floor(k) == floor_idx:
			var c := _key_cell(k)
			marks[c] = String(marks.get(c, "")) + "*"
	return marks


func _erase_floor_node_attrs(op_id: int, from_floor: int) -> void:
	for dict_root in [_route_waits, _route_orders]:
		if not dict_root.has(op_id):
			continue
		var d: Dictionary = dict_root[op_id]
		for k in d.keys():
			if _key_floor(k) == from_floor:
				d.erase(k)


static func _key_cell(k: Variant) -> Vector2i:
	if k is Vector3i:
		return Vector2i((k as Vector3i).x, (k as Vector3i).y)
	return k as Vector2i


static func _key_floor(k: Variant) -> int:
	if k is Vector3i:
		return (k as Vector3i).z
	return 0


func _node_storage_key(cell: Vector2i) -> Variant:
	if map != null and map.floor_count > 1:
		return Vector3i(cell.x, cell.y, _active_floor)
	return cell


func _on_route_committed(op_id: int, waypoints: Array[Vector2i]) -> void:
	if SimClock.phase != SimClock.Phase.PLANNING or op_id < 0 or op_id >= spawn_cells.size():
		return
	var fmap := world.map_on_floor(_active_floor) if world != null else map
	var segs: Array = _floor_segments.get(op_id, [])
	if segs.is_empty():
		segs = [{"floor": 0, "start": spawn_cells[op_id], "cells": [], "stair_to_floor": -1, "stair_to_cell": Vector2i.ZERO}]
	var seg_idx := _find_segment_index(segs, _active_floor)
	if seg_idx < 0:
		_set_status("Route %s to a stairwell to reach F%d first." % [squad_hud.callsign(op_id), _active_floor + 1])
		return
	while segs.size() > seg_idx + 1:
		var dropped: Dictionary = segs.pop_back()
		_erase_floor_node_attrs(op_id, int(dropped.get("floor", 0)))
	var seg: Dictionary = segs[seg_idx]
	var start: Vector2i = seg["start"]
	var result := RoutePlanner.plan(fmap, start, waypoints)
	var cells: Array[Vector2i] = result["cells"]
	var blocked: Vector2i = result["blocked_at"]
	var took_stair := {}
	if map != null and map.floor_count > 1 and blocked == RoutePlanner.NO_CELL and not cells.is_empty():
		var stair := fmap.stair_at(_active_floor, cells[cells.size() - 1])
		if not stair.is_empty():
			took_stair = stair
	seg["cells"] = cells
	seg["stair_to_floor"] = int(took_stair.get("to_floor", -1)) if not took_stair.is_empty() else -1
	seg["stair_to_cell"] = Vector2i(int(took_stair["to_cell"][0]), int(took_stair["to_cell"][1])) if not took_stair.is_empty() else Vector2i.ZERO
	segs[seg_idx] = seg
	_erase_floor_node_attrs(op_id, _active_floor)
	if not took_stair.is_empty():
		segs.append({
			"floor": int(seg["stair_to_floor"]),
			"start": seg["stair_to_cell"],
			"cells": [],
			"stair_to_floor": -1,
			"stair_to_cell": Vector2i.ZERO,
		})
	if map != null and map.floor_count > 1:
		_floor_segments[op_id] = segs
	else:
		_floor_segments.erase(op_id)
		route_cells[op_id] = cells
	_selected_node = RoutePlanner.NO_CELL
	squad_hud.touch_operative(op_id)
	_compile_route(op_id)
	if blocked != RoutePlanner.NO_CELL:
		_invalid_routes[op_id] = blocked
	else:
		_invalid_routes.erase(op_id)
	_rebuild_world()
	_refresh_floor_visuals()
	var who := squad_hud.callsign(op_id)
	if blocked != RoutePlanner.NO_CELL:
		_set_status("%s route blocked at %s. Redraw to continue." % [who, _cell_name(blocked)])
	elif not took_stair.is_empty():
		var next_f := int(seg["stair_to_floor"])
		_set_active_floor(next_f)
		_set_status("%s ascended stairs to F%d! Draw F%d route." % [who, next_f + 1, next_f + 1])
	else:
		var doors := (plans[op_id] as Array).size() - (route_cells[op_id] as Array).size()
		var action_note := " · %d door action%s" % [doors, "" if doors == 1 else "s"] if doors > 0 else ""
		_set_status("%s route set · %d cells%s. Tap route cell for orders." % [who, (route_cells[op_id] as Array).size(), action_note])


func _on_operative_selected(op_id: int) -> void:
	_selected_op = op_id
	_selected_node = RoutePlanner.NO_CELL
	for token in controller.tokens:
		token.set_selected(token.op_id == op_id)
	if SimClock.phase == SimClock.Phase.PLANNING:
		_set_phase_controls(false)
	elif SimClock.phase == SimClock.Phase.EXECUTION and tap_in != null:
		tap_in.op_id = op_id
		_set_status("TAP-IN %s · Tap any cell on map to redirect (-1 CP)." % squad_hud.callsign(op_id))


func _on_execution_cell_tapped(cell: Vector2i) -> void:
	if SimClock.phase != SimClock.Phase.EXECUTION or _result_view != null or world == null or tap_in == null:
		return
	var fmap := world.map_on_floor(_active_floor)
	if not fmap.in_bounds(cell) or fmap.is_solid(cell):
		return
	var target_id := tap_in.op_id if tap_in.op_id >= 0 else (_selected_op if _selected_op >= 0 else 0)
	var target_op: SimOperative = null
	for o in world.operatives:
		if o.id == target_id and o.faction_id == local_faction_id:
			target_op = o
			break
	if target_op == null or target_op.floor_idx != _active_floor:
		return
	if tap_in.ingest_cell_target(target_op, cell):
		_set_status("TAP-IN %s -> %s (CP %d/%d)" % [
			squad_hud.callsign(target_op.id),
			_cell_name(cell),
			world.tapin_points,
			SimConstants.TAPIN_COMMAND_POINTS_MAX,
		])
	elif world.tapin_points <= 0:
		_set_status("No Command Points left for Tap-In.")
	else:
		_set_status("Tap-In on cooldown for %s." % squad_hud.callsign(target_op.id))


func _on_route_node_tapped(cell: Vector2i) -> void:
	if SimClock.phase != SimClock.Phase.PLANNING or _result_view != null:
		return
	var fmap := world.map_on_floor(_active_floor) if world != null else map
	if not fmap.in_bounds(cell):
		return
	if controller != null and controller.tap_to_cell_mode:
		for i in range(spawn_cells.size()):
			if _planning_cell_for_op(i, _active_floor) == cell:
				if not _find_segment_on_floor(i, _active_floor).is_empty() or _active_floor == 0:
					squad_hud.touch_operative(i)
					_selected_node = cell if _has_route_node(i, cell) else RoutePlanner.NO_CELL
					_set_phase_controls(false)
					if _selected_node != RoutePlanner.NO_CELL:
						_show_selected_node()
					return
		var tap_op := _selected_op if _selected_op >= 0 else 0
		if not _has_route_node(tap_op, cell) and not fmap.is_solid(cell):
			var leg := _current_leg_cells(tap_op, _active_floor)
			var tail := leg[leg.size() - 1] if not leg.is_empty() else _planning_cell_for_op(tap_op, _active_floor)
			var step_path := GridPathfinder.find_path(fmap, tail, cell)
			if step_path.size() >= 2:
				var wps: Array[Vector2i] = []
				for c in leg:
					wps.append(c)
				for idx in range(1, step_path.size()):
					wps.append(step_path[idx])
				_on_route_committed(tap_op, wps)
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


func _current_leg_cells(op_id: int, floor_idx: int) -> Array[Vector2i]:
	if _floor_segments.has(op_id):
		var seg := _find_segment_on_floor(op_id, floor_idx)
		var out: Array[Vector2i] = []
		if not seg.is_empty():
			for c in seg.get("cells", []):
				out.append(c as Vector2i)
		return out
	var out2: Array[Vector2i] = []
	if floor_idx == 0 and route_cells.has(op_id):
		for c in route_cells[op_id]:
			out2.append(c as Vector2i)
	return out2


func _has_route_node(op_id: int, cell: Vector2i) -> bool:
	if _floor_segments.has(op_id):
		var seg := _find_segment_on_floor(op_id, _active_floor)
		if seg.is_empty():
			return false
		var leg: Array = seg.get("cells", [])
		return not leg.is_empty() and (cell == seg["start"] or leg.has(cell))
	if _active_floor != 0 or not route_cells.has(op_id):
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
	var k3 := Vector3i(cell.x, cell.y, _active_floor)
	if orders.has(k3):
		return orders[k3]
	if _active_floor == 0 and orders.has(cell):
		return orders[cell]
	return {}


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
	var w_val: Variant = RoutePlanner._node_entry(waits, cell, _active_floor, false)
	if w_val != null:
		parts.append("WAIT " + String(w_val).to_upper())
	if order.has("action"):
		parts.append(_action_label(int(order["action"])))
	return " · ".join(parts)


static func _facing_label(bearing: int) -> String:
	if bearing < 0:
		return "FACE FREE"
	if bearing == 0:
		return "FACE E"
	if bearing == 90:
		return "FACE S"
	if bearing == 180:
		return "FACE W"
	if bearing == 270:
		return "FACE N"
	return "FACE %d" % bearing


static func _action_label(kind: int) -> String:
	if kind == int(AgentCommand.ActionKind.FLASHBANG):
		return "FLASHBANG"
	if kind == int(AgentCommand.ActionKind.FRAG):
		return "FRAG"
	if kind == int(AgentCommand.ActionKind.TEAR_GAS):
		return "GAS"
	return "ACTION"


func _build_node_menu(settings: Dictionary) -> void:
	_node_menu = PanelContainer.new()
	_node_menu.name = "NodeMenu"
	_node_menu.visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_node_menu.add_child(col)
	var rows := [
		["STANCE", "stance", [["CAUTIOUS", &"cautious"], ["NORMAL", &"normal"], ["BLITZ", &"blitz"]]],
		["MODE", "mode", [["ENGAGE", &"engage"], ["ADVANCE", &"advance"], ["ESCORT", &"escort"]]],
		["ACTION", "action", [["FLASH", AgentCommand.ActionKind.FLASHBANG], ["FRAG", AgentCommand.ActionKind.FRAG], ["GAS", AgentCommand.ActionKind.TEAR_GAS]]],
		["FACE", "fof", [["N", 270], ["E", 0], ["S", 90], ["W", 180], ["FREE", -1]]],
	]
	for row in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		var title := Label.new()
		title.text = String(row[0])
		title.custom_minimum_size = Vector2(88, 0)
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 18)
		line.add_child(title)
		for opt in row[2]:
			var b := UiKit.button(String(opt[0]), _set_node_order.bind(String(row[1]), opt[1]), settings)
			b.toggle_mode = true
			b.custom_minimum_size = Vector2(0, NODE_BUTTON_PX)
			b.add_theme_font_size_override("font_size", 18)
			b.clip_text = true
			b.name = "Node_%s_%s" % [String(row[1]), String(opt[0])]
			_node_buttons[b.name] = [String(row[1]), opt[1], b]
			line.add_child(b)
		col.add_child(line)
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 8)
	var clear_btn := UiKit.button("CLEAR NODE", _clear_node, settings)
	clear_btn.name = "Node_clear"
	clear_btn.custom_minimum_size = Vector2(0, NODE_BUTTON_PX)
	clear_btn.add_theme_font_size_override("font_size", 18)
	clear_btn.clip_text = true
	bottom_row.add_child(clear_btn)
	var done_btn := UiKit.button("DONE", _dismiss_node_menu, settings)
	done_btn.name = "Node_done"
	done_btn.custom_minimum_size = Vector2(0, NODE_BUTTON_PX)
	done_btn.add_theme_font_size_override("font_size", 18)
	done_btn.clip_text = true
	bottom_row.add_child(done_btn)
	col.add_child(bottom_row)
	_hud_canvas.add_child(_node_menu)


func _dismiss_node_menu() -> void:
	_selected_node = RoutePlanner.NO_CELL
	_set_phase_controls(false)
	_set_status(_planning_hint())


func _set_node_order(key: String, value: Variant) -> void:
	if SimClock.phase != SimClock.Phase.PLANNING or _result_view != null or _selected_node == RoutePlanner.NO_CELL:
		return
	var orders: Dictionary = _route_orders.get(_selected_op, {})
	var k: Variant = _node_storage_key(_selected_node)
	var order: Dictionary = orders.get(k, {})
	if order.has(key) and order[key] == value:
		order.erase(key)
	else:
		order[key] = value
	if order.is_empty():
		orders.erase(k)
	else:
		orders[k] = order
	_route_orders[_selected_op] = orders
	_compile_route(_selected_op)
	_rebuild_world()
	_show_selected_node()


func _clear_node() -> void:
	if SimClock.phase != SimClock.Phase.PLANNING or _selected_node == RoutePlanner.NO_CELL:
		return
	var k: Variant = _node_storage_key(_selected_node)
	var orders: Dictionary = _route_orders.get(_selected_op, {})
	orders.erase(k)
	orders.erase(_selected_node)
	_route_orders[_selected_op] = orders
	var waits: Dictionary = _route_waits.get(_selected_op, {})
	waits.erase(k)
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
	var waits: Dictionary = _route_waits.get(op_id, {})
	var orders: Dictionary = _route_orders.get(op_id, {})
	if _floor_segments.has(op_id):
		var segs: Array = _floor_segments[op_id]
		var all_cells: Array[Vector2i] = []
		for seg in segs:
			for c in seg.get("cells", []):
				all_cells.append(c as Vector2i)
		route_cells[op_id] = all_cells
		plans[op_id] = RoutePlanner.compile_multi_floor(world.floor_maps, segs, waits, orders)
	else:
		var cells: Array[Vector2i] = route_cells[op_id]
		plans[op_id] = RoutePlanner.compile_commands(map, spawn_cells[op_id], cells, waits, orders)
	controller.show_waits(op_id, _marks_on_floor(op_id, _active_floor))


static func _cell_name(cell: Vector2i) -> String:
	return "%s%02d" % [MapRenderer.col_letter(cell.x), cell.y + 1]


func _rebuild_world() -> void:
	var seed_val := int(two_player_config.get("seed", DEV_SEED))
	world.setup(map, seed_val)
	if tap_in != null:
		tap_in.world = world
	_reached_checkpoints.clear()
	renderer.setup(world.map_on_floor(_active_floor))
	if props != null:
		props.map = world.map_on_floor(_active_floor)
		props.rebuild()
	_populate_world()
	_sync_tokens()
	if squad_hud != null:
		squad_hud.refresh(world)


func _set_phase_controls(executing: bool) -> void:
	var result_visible := _result_view != null
	if _menu_button != null:
		_menu_button.visible = not result_visible
	if _status_label != null:
		_status_label.visible = not result_visible
	if _hud != null:
		_hud.visible = not result_visible
	if squad_hud != null:
		squad_hud.visible = not result_visible
	if _execute_button != null:
		_execute_button.disabled = executing or result_visible
		if _is_pass_play() and not executing:
			_execute_button.text = "COMMIT P1" if _pass_play_stage == 0 else "EXEC P2"
		else:
			_execute_button.text = "EXECUTE"
	if _mode_button != null:
		_mode_button.visible = not result_visible
		_mode_button.disabled = result_visible
		if executing:
			_mode_button.text = "REL AI"
		elif controller != null:
			_mode_button.text = "TAP" if controller.tap_to_cell_mode else "DRAW"
	if _floor_button != null:
		_floor_button.visible = (map != null and map.floor_count > 1) and not result_visible
	var code_buttons := [_alpha_button, _bravo_button, _charlie_button, _delta_button]
	for i in range(code_buttons.size()):
		var b: Button = code_buttons[i]
		if b != null:
			b.disabled = result_visible or (not executing and _selected_node == RoutePlanner.NO_CELL)
			b.text = ("GO:" if executing else "W:") + "ABCD".substr(i, 1)
	if controller != null:
		controller.routing_enabled = not executing and not result_visible
	_refresh_node_menu()


func _set_status(msg: String) -> void:
	if _status_label != null:
		_status_label.text = msg


func _load_mission_targets() -> void:
	_checkpoints.clear()
	_exits.clear()
	for fl in range(map.floor_count):
		var fm := map.slice_map(fl)
		for objective in fm.objectives:
			var cell := MapEditorValidator.cell_of(objective.get("cell", []))
			var c3 := Vector3i(cell.x, cell.y, fl)
			if fm.in_bounds(cell) and not _checkpoints.has(c3):
				_checkpoints.append(c3)
		for zone in fm.extraction_zones:
			for entry in zone.get("cells", []):
				var cell := MapEditorValidator.cell_of(entry)
				var c3 := Vector3i(cell.x, cell.y, fl)
				if fm.in_bounds(cell) and not _exits.has(c3):
					_exits.append(c3)


func _planning_hint() -> String:
	if _checkpoints.is_empty() and _exits.is_empty():
		return "Ground-floor practice. " + ROUTE_HINT
	var goal := "Reach the marked checkpoints. " if not _checkpoints.is_empty() else ""
	if not _exits.is_empty():
		goal += "Finish a route at an amber exit. "
	if map != null and map.floor_count > 1:
		goal = ("Multi-floor (%dF). Route to cyan stair tiles. " % map.floor_count) + goal
	return goal + ROUTE_HINT


func _maybe_aar() -> void:
	if _is_pvp():
		var f0_alive := 0
		var f1_alive := 0
		var all_fin := true
		for op in world.operatives:
			if op.faction_id == 0 and op.is_alive():
				f0_alive += 1
			elif op.faction_id == 1 and op.is_alive():
				f1_alive += 1
			all_fin = all_fin and (op.done or op.halted or not op.is_alive())
		if f1_alive == 0:
			_show_result(true, "P1 Breachers eliminated P2 Defenders.", f0_alive, false)
			return
		if f0_alive == 0:
			_show_result(false, "P2 Defenders eliminated P1 Breachers.", f0_alive, false)
			return
		if all_fin and world.pending.is_empty() and world.entities.is_empty():
			_show_result(true, "PvP breach phase completed.", f0_alive, false)
		return
	var alive := 0
	var all_finished := true
	var halted := false
	var at_exit := false
	for op in world.operatives:
		if op.is_alive():
			alive += 1
		all_finished = all_finished and (op.done or op.halted or not op.is_alive())
		halted = halted or op.halted
		var cell := GridUtil.cell_of(op.pos)
		var c3 := Vector3i(cell.x, cell.y, op.floor_idx)
		if _checkpoints.has(c3):
			_reached_checkpoints[c3] = true
		at_exit = at_exit or (op.done and _exits.has(c3))
	var mission := world.check_mission()
	if alive == 0:
		_show_result(false, "No operatives remaining.", alive, halted)
	elif bool(mission.get("complete", false)) and all_finished and world.pending.is_empty() and world.entities.is_empty():
		var complete := not halted and _reached_checkpoints.size() == _checkpoints.size() and (_exits.is_empty() or at_exit)
		var reason := "All routes completed."
		if halted:
			reason = "An operative halted before completing the plan."
		elif _reached_checkpoints.size() != _checkpoints.size():
			reason = "One or more checkpoints were missed."
		elif not _exits.is_empty() and not at_exit:
			reason = "No operative finished at an exit."
		_show_result(complete, reason, alive, halted)


func _next_campaign_map() -> String:
	var idx := CampaignScreen.MISSION_PATHS.find(map_source)
	if idx >= 0 and idx + 1 < CampaignScreen.MISSION_PATHS.size():
		return CampaignScreen.MISSION_PATHS[idx + 1]
	return ""


func _show_result(complete: bool, reason: String, alive: int, halted: bool = false) -> void:
	_recorded_go_codes = world.go_code_stream.duplicate(true)
	_recorded_overrides.clear()
	for oc in world.override_stream:
		_recorded_overrides.append(OverrideCommand.from_dict(oc.to_dict()))
	_recorded_max_tick = world.tick
	var grading := MissionGrading.new().grade(world, complete)
	var rp_earned := int(grading.get("rp", 0))
	var zero_cas := alive == world.operatives.size()
	var letter := MissionGrading.letter_for(complete, zero_cas, halted)
	if complete and map_source != "" and map_source != GREYBOX_SOURCE and two_player_config.is_empty():
		var ps := ProgressionSave.load_from_disk()
		ps.campaign_state["total_rp"] = int(ps.campaign_state.get("total_rp", 0)) + rp_earned
		ps.campaign_state[map_source] = letter
		ps.save_to_disk()
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
		"grade": letter,
		"rp": rp_earned,
		"next_map_path": _next_campaign_map(),
		"journal": world.journal.duplicate(true),
	}
	_result_view.retry_requested.connect(_on_reset_pressed)
	_result_view.leave_requested.connect(_go_back)
	_result_view.scrub_requested.connect(scrub_replay_to_tick)
	_result_view.replay_requested.connect(_on_replay_requested)
	_result_view.next_mission_requested.connect(_on_next_mission)
	_hud_canvas.add_child(_result_view)
	SimClock.reset_to_planning()
	_set_phase_controls(false)


func _on_next_mission(next_path: String) -> void:
	ScreenRouter.set_param("map_path", next_path)
	ScreenRouter.set_param("return_stage", int(ScreenRouter.Stage.CAMPAIGN))
	ScreenRouter.goto_stage(ScreenRouter.Stage.PREP)


func scrub_replay_to_tick(target_tick: int) -> void:
	if _initial_snapshot == null or world == null:
		return
	world.restore_from_data(_initial_snapshot.data)
	world.go_code_stream = _recorded_go_codes.duplicate(true)
	world.override_stream.clear()
	for oc in _recorded_overrides:
		world.override_stream.append(OverrideCommand.from_dict(oc.to_dict()))
	if fog != null:
		fog.reset_fog()
	if overlay != null:
		overlay.reset()
	if vfx != null:
		vfx.clear()
	var steps := clampi(target_tick, 0, _recorded_max_tick)
	for i in range(steps):
		world.step()
	if not world.operatives.is_empty():
		var target_fl := world.operatives[0].floor_idx
		if target_fl != _active_floor:
			_active_floor = target_fl
			if controller != null:
				controller.active_floor = _active_floor
				controller.map = world.map_on_floor(_active_floor)
			if _floor_button != null and map != null:
				_floor_button.text = "F%d/%d" % [_active_floor + 1, map.floor_count]
	if renderer != null:
		renderer.setup(world.map_on_floor(_active_floor))
	if props != null:
		props.map = world.map_on_floor(_active_floor)
		props.rebuild()
	_sync_tokens()
	_update_fog()
	if squad_hud != null:
		squad_hud.refresh(world)


func _on_replay_requested() -> void:
	if _result_view != null:
		var rv := _result_view
		_result_view = null
		rv.visible = false
		rv.queue_free()
	_active_floor = 0
	if controller != null:
		controller.active_floor = 0
		controller.map = world.map_on_floor(0)
	if _floor_button != null and map != null:
		_floor_button.text = "F1/%d" % map.floor_count
	scrub_replay_to_tick(0)
	_reached_checkpoints.clear()
	_pending_go_codes.clear()
	SimClock.start_execution()
	_set_phase_controls(true)
	_set_status("REPLAYING recorded plan...")


func _populate_world() -> void:
	_consumed_enemy_spawns = 2 if _is_pvp() else 0
	for i in range(spawn_cells.size()):
		var plan: Array[AgentCommand] = []
		if plans.has(i):
			for cmd in plans[i]:
				plan.append(cmd)
		var op := world.add_operative(i, spawn_cells[i], plan, 0)
		if _is_pvp() and i >= 2:
			op.faction_id = 1
		if i < mission_loadout.size():
			var cfg: Dictionary = mission_loadout[i]
			op.armor_class = StringName(String(cfg.get("armor_class", "light")))
			op.heartbeat_radius = int(cfg.get("heartbeat_radius", 0))
			world.combat.calibers[op.id] = StringName(String(cfg.get("caliber", "5.56")))
	var eid := maxi(OPERATIVE_COUNT, spawn_cells.size())
	var skipped := 0
	for fl in range(world.floor_maps.size()):
		var fm := world.floor_maps[fl]
		for entry in fm.ai_spawns:
			var cell := MapEditorValidator.cell_of(entry.get("cell", []))
			if fm.in_bounds(cell) and not fm.is_solid(cell):
				if fl == 0 and skipped < _consumed_enemy_spawns:
					skipped += 1
					continue
				world.add_enemy(eid, cell, StringName(String(entry.get("archetype", ""))), float(entry.get("facing_deg", 0.0)), fl)
				eid += 1


func _load_session_configs() -> void:
	var raw_loadout: Variant = ScreenRouter.get_param("mission_loadout", [])
	ScreenRouter.clear_param("mission_loadout")
	if typeof(raw_loadout) == TYPE_ARRAY:
		mission_loadout = (raw_loadout as Array).duplicate(true)
	var raw_2p: Variant = ScreenRouter.get_param("two_player_config", {})
	ScreenRouter.clear_param("two_player_config")
	if typeof(raw_2p) == TYPE_DICTIONARY:
		two_player_config = (raw_2p as Dictionary).duplicate(true)
	if String(two_player_config.get("transport", "")) == "lan" and lockstep != null:
		var role := String(two_player_config.get("role", "host"))
		if role == "host":
			lockstep.host_on_port(0, LockstepSession.PORT)
		else:
			lockstep.connect_on_port(String(two_player_config.get("host_ip", "127.0.0.1")), LockstepSession.PORT)
			if _is_pvp():
				local_faction_id = 1
	if overlay != null:
		overlay.local_faction_id = local_faction_id


func _is_2p() -> bool:
	return not two_player_config.is_empty()


func _is_pvp() -> bool:
	return String(two_player_config.get("mode", "")) == "pvp"


func _is_pass_play() -> bool:
	return String(two_player_config.get("transport", "")) == "pass_play"


func _assigned_squad_for(op_id: int) -> StringName:
	if op_id >= 0 and op_id < mission_loadout.size():
		return StringName(String((mission_loadout[op_id] as Dictionary).get("squad", "red")))
	return SquadConfig.SQUADS[op_id % SquadConfig.SQUADS.size()]


func _resolve_spawn_cells() -> Array[Vector2i]:
	if _is_pvp():
		var breacher_cells := spawn_cells_for(map, map_source == GREYBOX_SOURCE, 2)
		var def_cells: Array[Vector2i] = []
		for entry in map.ai_spawns:
			var dc := MapEditorValidator.cell_of(entry.get("cell", []))
			if map.in_bounds(dc) and not map.is_solid(dc) and not breacher_cells.has(dc) and not def_cells.has(dc):
				def_cells.append(dc)
				if def_cells.size() >= 2:
					break
		var extra := spawn_cells_for(map, map_source == GREYBOX_SOURCE, 4)
		for ec in extra:
			if def_cells.size() >= 2:
				break
			if not breacher_cells.has(ec) and not def_cells.has(ec):
				def_cells.append(ec)
		var combined: Array[Vector2i] = []
		for bc in breacher_cells:
			combined.append(bc)
		for dc2 in def_cells:
			combined.append(dc2)
		return combined
	var count := clampi(mission_loadout.size(), 2, 4) if not mission_loadout.is_empty() else OPERATIVE_COUNT
	return spawn_cells_for(map, map_source == GREYBOX_SOURCE, count)


func _turn_ops(player_idx: int) -> Array[int]:
	var out: Array[int] = []
	if not _is_2p():
		for i in range(spawn_cells.size()):
			out.append(i)
		return out
	if _is_pvp():
		if player_idx == 0:
			out = [0, 1]
		else:
			out = [2, 3]
		return out
	out = [player_idx] if player_idx < spawn_cells.size() else [0]
	return out


func _apply_turn_controllability() -> void:
	if controller == null:
		return
	controller.controllable_ops.clear()
	if not _is_2p() or SimClock.phase == SimClock.Phase.EXECUTION:
		local_faction_id = 0
		if squad_hud != null:
			squad_hud.active_faction_id = 0
			squad_hud.refresh(world)
		if overlay != null:
			overlay.local_faction_id = 0
		return
	var p_idx := _pass_play_stage if _is_pass_play() else (0 if String(two_player_config.get("role", "host")) == "host" else 1)
	var allowed := _turn_ops(p_idx)
	for op_id in allowed:
		controller.controllable_ops[op_id] = true
	if _is_pvp():
		local_faction_id = p_idx
	if squad_hud != null:
		squad_hud.active_faction_id = local_faction_id
		squad_hud.refresh(world)
		if not allowed.is_empty():
			squad_hud.selected_op = allowed[0]
			_selected_op = allowed[0]
	if overlay != null:
		overlay.local_faction_id = local_faction_id
	for i in range(spawn_cells.size()):
		var line := controller.route_line(i)
		if line != null:
			line.visible = (not _is_pass_play() or allowed.has(i))
	for tok in controller.tokens:
		tok.visible = not (_is_pass_play() and _pass_play_stage == 1 and _is_pvp() and tok.op_id < 2)


func _reveal_all_plans_for_execution() -> void:
	if controller == null:
		return
	controller.controllable_ops.clear()
	local_faction_id = 0
	if squad_hud != null:
		squad_hud.active_faction_id = 0
		squad_hud.refresh(world)
	if overlay != null:
		overlay.local_faction_id = 0
	for i in range(spawn_cells.size()):
		var line := controller.route_line(i)
		if line != null:
			line.visible = true
	_sync_tokens()


func _serialize_ops_plans(op_ids: Array[int]) -> String:
	var dump := {}
	for op_id in op_ids:
		var arr := []
		for cmd in plans.get(op_id, []):
			arr.append((cmd as AgentCommand).to_dict())
		dump[str(op_id)] = arr
	return JSON.stringify(dump)


func _consume_lan_packets() -> void:
	if lockstep == null:
		return
	while not lockstep.received_packets.is_empty():
		var pkt: Dictionary = lockstep.received_packets.pop_front()
		if String(pkt.get("kind", "")) == "plan_sync":
			var parsed: Variant = JSON.parse_string(String(pkt.get("plans", "{}")))
			if typeof(parsed) == TYPE_DICTIONARY:
				var d: Dictionary = parsed
				for k in d.keys():
					var op_id := int(k)
					var arr: Array[AgentCommand] = []
					for cd in d[k]:
						arr.append(AgentCommand.from_dict(cd))
					plans[op_id] = arr
				_rebuild_world()


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
