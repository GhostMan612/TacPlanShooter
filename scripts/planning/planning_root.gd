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
var fog_segment_rebuilds := 0
var fog_poly_computes := 0
var _segs: Array = []
var _segs_sig := ""
var _sight_cache := {}
var prep_flow: MissionPrepFlow = null
var local_faction_id: int = 0

const OPERATIVE_COUNT := 2
const GREYBOX_SOURCE := "greybox_default"

const ROUTE_HINT := "Long-press an operative, then drag to draw its route."

var squads := SquadConfig.new()
var spawn_cells: Array[Vector2i] = []
var plans := {}
var route_cells := {}
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
	_apply_theme()
	renderer = MapRenderer.new()
	renderer.apply_palette(_tm.palette())
	renderer.setup(map)
	add_child(renderer)
	fog = FogLayer.new()
	fog.setup(map)
	fog.apply_palette(_tm.palette())
	add_child(fog)
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
	add_child(controller)
	get_viewport().size_changed.connect(_on_viewport_resized)
	world = SimWorld.new()
	world.setup(map, DEV_SEED)
	_populate_world()
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
		world.step()
		_sync_tokens()
		_update_fog()
		if squad_hud != null:
			squad_hud.refresh(world)
		_maybe_aar()


func _sync_tokens() -> void:
	if world == null or controller == null:
		return
	var s := float(SimConstants.GRID_CELL_SIZE_PX)
	for o in world.operatives:
		for token in controller.tokens:
			if token.op_id == o.id:
				token.sync_from(o, o.pos * s)


func _door_signature() -> String:
	var parts := PackedStringArray()
	for k in map.door_cells.keys():
		parts.append("%d,%d=%s" % [int(k.x), int(k.y), "1" if bool(map.door_open.get(k, false)) else "0"])
	return ";".join(parts) + "|%d" % map.solid_cells.size()


func _wall_segments() -> Array:
	var sig := _door_signature()
	if sig != _segs_sig:
		_segs = map.get_wall_segments()
		_segs_sig = sig
		_sight_cache.clear()
		fog_segment_rebuilds += 1
	return _segs


func _sight(key: int, pos: Vector2, segs: Array) -> Dictionary:
	var pos_key := "%.6f,%.6f" % [pos.x, pos.y]
	if _sight_cache.has(key):
		var cached: Dictionary = _sight_cache[key]
		if String(cached["key"]) == pos_key:
			return cached
	var poly := Visibility.compute_polygon(pos, segs, SimConstants.LOS_VERTEX_EPSILON_RAD)
	fog_poly_computes += 1
	var entry := {"key": pos_key, "cells": poly, "px": _cells_to_px(poly)}
	_sight_cache[key] = entry
	return entry


func _update_fog() -> void:
	if fog == null or map == null or world == null:
		return
	var segs := _wall_segments()
	var cell_polys := []
	var px_polys := []
	for o in world.operatives:
		if o.faction_id != local_faction_id or not o.is_alive():
			continue
		var sight := _sight(o.id, o.pos, segs)
		var poly: PackedVector2Array = sight["cells"]
		if poly.size() >= 3:
			cell_polys.append(poly)
			px_polys.append(sight["px"])
	for i in range(world.drones.size()):
		var d: SimDrone = world.drones[i]
		if d.destroyed:
			continue
		var dsight := _sight(-1 - i, d.pos, segs)
		var dpoly: PackedVector2Array = dsight["cells"]
		if dpoly.size() >= 3:
			cell_polys.append(dpoly)
			px_polys.append(dsight["px"])
	fog.update_polys(px_polys)
	if overlay != null:
		overlay.update_contacts(world, cell_polys)


static func _cells_to_px(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var s := float(SimConstants.GRID_CELL_SIZE_PX)
	for p in poly:
		out.append(p * s)
	return out


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
	_configure_tokens(pal)
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
	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.text = ROUTE_HINT
	_hud_canvas.add_child(_status_label)
	_set_phase_controls(false)
	squad_hud = SquadHud.new()
	squad_hud.squads = squads
	_hud_canvas.add_child(squad_hud)
	squad_hud.apply_palette(_tm.palette())
	squad_hud.refresh(world)
	for c in [_menu_button, _hud, squad_hud, _status_label]:
		(c as Control).theme = _tm.applied_theme
	squad_hud.operative_selected.connect(_on_operative_selected)
	_configure_tokens(_tm.palette())
	_sync_tokens()
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
	_pending_go_codes.clear()
	SimClock.start_execution()
	_set_phase_controls(true)
	fog.reset_fog()
	fog.set_active(true)
	_update_fog()
	var routed := 0
	for k in plans.keys():
		if not (plans[k] as Array).is_empty():
			routed += 1
	_set_status("EXECUTING: %d of %d operatives routed" % [routed, spawn_cells.size()])


func _queue_go_code(code: StringName) -> void:
	if world == null or SimClock.phase != SimClock.Phase.EXECUTION:
		return
	if not _pending_go_codes.has(code):
		_pending_go_codes.append(code)
	_set_status("GO-CODE " + String(code).to_upper() + " sent")


func _on_alpha_pressed() -> void:
	_queue_go_code(&"alpha")


func _on_bravo_pressed() -> void:
	_queue_go_code(&"bravo")


func _on_charlie_pressed() -> void:
	_queue_go_code(&"charlie")


func _on_delta_pressed() -> void:
	_queue_go_code(&"delta")


func _on_reset_pressed() -> void:
	if world == null:
		return
	_pending_go_codes.clear()
	SimClock.reset_to_planning()
	_rebuild_world()
	_set_phase_controls(false)
	fog.reset_fog()
	if overlay != null:
		overlay.reset()
	_set_status(ROUTE_HINT if plans.is_empty() else "RESET: routes kept, ready to execute")


func _on_route_committed(op_id: int, waypoints: Array[Vector2i]) -> void:
	if SimClock.phase != SimClock.Phase.PLANNING or op_id < 0 or op_id >= spawn_cells.size():
		return
	var start: Vector2i = spawn_cells[op_id]
	var result := RoutePlanner.plan(map, start, waypoints)
	var cells: Array[Vector2i] = result["cells"]
	var commands: Array[AgentCommand] = result["commands"]
	var blocked: Vector2i = result["blocked_at"]
	plans[op_id] = commands
	route_cells[op_id] = cells
	controller.show_route(op_id, RoutePlanner.path_points_px(start, cells))
	_rebuild_world()
	var who := squad_hud.callsign(op_id) if squad_hud != null else "OP%d" % op_id
	if blocked != RoutePlanner.NO_CELL:
		_set_status("%s ROUTE BLOCKED AT %s%02d (%d cells kept)" % [who, MapRenderer.col_letter(blocked.x), blocked.y + 1, cells.size()])
	else:
		_set_status("%s ROUTE SET: %d cells" % [who, cells.size()])


func _configure_tokens(pal: Dictionary) -> void:
	if controller == null:
		return
	var ink: Color = pal.get("ink", Color(0.9, 0.92, 0.95))
	for token in controller.tokens:
		var squad := SquadConfig.SQUADS[token.op_id % SquadConfig.SQUADS.size()]
		if squad_hud != null:
			squad = squad_hud.squad_of(token.op_id)
		var sign_text := squad_hud.callsign(token.op_id) if squad_hud != null else ""
		token.configure(PlanBoard.squad_color(squad), sign_text, ink)


func _on_operative_selected(op_id: int) -> void:
	if controller == null:
		return
	for token in controller.tokens:
		token.set_selected(token.op_id == op_id)


func _rebuild_world() -> void:
	world.setup(map, DEV_SEED)
	_populate_world()
	_sync_tokens()
	if squad_hud != null:
		squad_hud.refresh(world)


func _set_phase_controls(executing: bool) -> void:
	if _execute_button != null:
		_execute_button.disabled = executing
	for b in [_alpha_button, _bravo_button, _charlie_button, _delta_button]:
		if b != null:
			(b as Button).disabled = not executing
	if controller != null:
		controller.routing_enabled = not executing


func _set_status(msg: String) -> void:
	if _status_label != null:
		_status_label.text = msg


func _maybe_aar() -> void:
	if world == null or world.operatives.is_empty():
		return
	var friendlies := 0
	var all_down := true
	for o in world.operatives:
		if o.faction_id != local_faction_id:
			continue
		friendlies += 1
		if o.is_alive():
			all_down = false
			break
	if friendlies == 0 or not all_down:
		return
	var aar := AarScreen.new()
	aar.world = world
	add_child(aar)
	SimClock.reset_to_planning()
	_set_phase_controls(false)
	_set_status("ALL OPERATIVES DOWN")
	_sync_tokens()


func _populate_world() -> void:
	for i in range(spawn_cells.size()):
		var plan: Array[AgentCommand] = []
		if plans.has(i):
			for cmd in plans[i]:
				plan.append(cmd)
		world.add_operative(i, spawn_cells[i], plan)


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
