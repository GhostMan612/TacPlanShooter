# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name PlanningController
extends Node

signal mode_changed(mode: int)
signal route_committed(op_id: int, waypoints: Array[Vector2i])
signal cell_tapped(cell: Vector2i)

enum Mode { OBSERVATION, ROUTING }

const LONG_PRESS_SEC := 0.28
const TAP_MAX_SEC := 0.32
const SLOP_PX := 12.0
const HOLD_SLOP_PX := 24.0
const SELECT_RADIUS_SCREEN_PX := 80.0
const PREVIEW_COLOR := Color(0.25, 0.85, 1.0, 0.9)
const COMMITTED_COLOR := Color(0.25, 0.85, 1.0, 0.5)

var camera: MissionCamera = null
var map: GreyboxMap = null
var loupe: PipLoupe = null
var tokens: Array[OperativeToken] = []
var board := PlanBoard.new()
var line_container: Node2D = null
var mode := Mode.OBSERVATION
var routing_enabled := true
var tap_to_cell_mode := false
var active_floor := 0
var op_colors := {}

var _touches := {}
var _press_time := {}
var _press_origin := {}
var _long_fired := {}
var _routing_finger := -1
var _routing_token: OperativeToken = null
var _raw_route := PackedVector2Array()
var _kept_route := PackedVector2Array()
var _preview: Line2D = null
var _route_lines := {}
var _pinch_base_dist := 0.0
var _pinch_base_zoom := 1.0
var _tap_selected_op: int = -1


func _process(delta: float) -> void:
	var fired_now: Array = []
	for idx in _press_time.keys():
		_press_time[idx] += delta
		if bool(_long_fired.get(idx, false)):
			continue
		var origin: Vector2 = _press_origin[idx]
		var cur: Vector2 = _touches.get(idx, origin)
		if origin.distance_to(cur) >= HOLD_SLOP_PX:
			_long_fired[idx] = true
			continue
		if _press_time[idx] >= LONG_PRESS_SEC and _touches.size() == 1 and mode == Mode.OBSERVATION:
			_long_fired[idx] = true
			fired_now.append(idx)
	for idx in fired_now:
		_try_begin_routing(idx, _touches.get(idx, Vector2.ZERO))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_press(event.index, event.position)
		else:
			_on_release(event.index, event.position)
	elif event is InputEventScreenDrag:
		_on_drag(event.index, event.position, event.relative)


func _on_press(idx: int, pos: Vector2) -> void:
	_touches[idx] = pos
	_press_time[idx] = 0.0
	_press_origin[idx] = pos
	_long_fired[idx] = false
	if _touches.size() == 2 and mode == Mode.OBSERVATION:
		_anchor_pinch()


func _on_release(idx: int, pos: Vector2) -> void:
	var dt: float = _press_time.get(idx, 999.0)
	var origin: Vector2 = _press_origin.get(idx, pos)
	var moved := origin.distance_to(pos) >= SLOP_PX
	var long_fired: bool = bool(_long_fired.get(idx, false))
	var was_routing := idx == _routing_finger
	_touches.erase(idx)
	_press_time.erase(idx)
	_press_origin.erase(idx)
	_long_fired.erase(idx)
	if was_routing:
		_commit_route()
		return
	if mode != Mode.OBSERVATION:
		return
	if _touches.size() == 2:
		_anchor_pinch()
	else:
		_pinch_base_dist = 0.0
	if dt <= TAP_MAX_SEC and not moved and not long_fired and _touches.size() == 0:
		_handle_tap(pos)
		var ta := get_node_or_null("/root/TacticalAudio")
		if ta != null:
			ta.play_blip(&"")


func _on_drag(idx: int, pos: Vector2, relative: Vector2) -> void:
	if not _touches.has(idx):
		return
	_touches[idx] = pos
	if idx == _routing_finger and mode == Mode.ROUTING:
		_extend_route(_to_world(pos))
		if loupe != null and _preview != null:
			var vp_sz := get_viewport().get_visible_rect().size
			loupe.show_at(pos, _to_world(pos), vp_sz, map, _preview.points, PREVIEW_COLOR)
		return
	if mode != Mode.OBSERVATION or camera == null:
		return
	if _touches.size() == 1:
		camera.pan_by(relative)
	elif _touches.size() == 2 and _pinch_base_dist > 0.0:
		var keys := _touches.keys()
		var a: Vector2 = _touches[keys[0]]
		var b: Vector2 = _touches[keys[1]]
		camera.zoom_about(_pinch_base_zoom * (a.distance_to(b) / _pinch_base_dist), (a + b) * 0.5)


func _anchor_pinch() -> void:
	var keys := _touches.keys()
	var a: Vector2 = _touches[keys[0]]
	var b: Vector2 = _touches[keys[1]]
	_pinch_base_dist = a.distance_to(b)
	_pinch_base_zoom = camera.base_zoom() if camera != null else 1.0


func _extend_route(world: Vector2) -> void:
	_raw_route.append(world)
	if _kept_route[_kept_route.size() - 1].distance_to(world) < RouteSanitizer.MIN_POINT_DIST_PX:
		return
	_kept_route.append(world)
	_preview.points = RouteSanitizer.bake_smooth(_kept_route)


func _try_begin_routing(idx: int, vp_pos: Vector2) -> void:
	if not routing_enabled:
		return
	var world := _to_world(vp_pos)
	var zoom_x: float = camera.zoom.x if camera != null else 1.0
	var best: OperativeToken = null
	var best_d := SELECT_RADIUS_SCREEN_PX / zoom_x
	for t in tokens:
		if not t.visible or t.modulate.a < 0.5:
			continue
		var d := t.position.distance_to(world)
		if d < best_d:
			best_d = d
			best = t
	if best == null:
		return
	_routing_finger = idx
	_routing_token = best
	best.set_routing_highlight(true)
	mode = Mode.ROUTING
	var ta := get_node_or_null("/root/TacticalAudio")
	if ta != null:
		ta.play_blip(&"")
	if bool(ThemeManager.load_settings().get("haptics", true)):
		Input.vibrate_handheld(16)
	if camera != null and vp_pos.y > camera.get_viewport_rect().size.y * 0.72:
		camera.set_finger_offset(Vector2(0.0, -72.0))
	_raw_route = PackedVector2Array([best.position])
	_kept_route = PackedVector2Array([best.position])
	_ensure_preview()
	_preview.points = PackedVector2Array([best.position])
	if loupe != null:
		var vp_sz := get_viewport().get_visible_rect().size
		loupe.show_at(vp_pos, world, vp_sz, map, _preview.points, PREVIEW_COLOR)
	mode_changed.emit(mode)
	print("[PLAN] routing op %d" % best.op_id)


func _commit_route() -> void:
	var op_id := _routing_token.op_id
	_preview.points = PackedVector2Array()
	if _kept_route.size() < 2:
		print("[PLAN] op %d route cancelled (too short)" % op_id)
		_exit_routing()
		return
	var pts := RouteSanitizer.bake_smooth(RouteSanitizer.decimate(_raw_route))
	var cells := RoutePlanner.repair_freehand_waypoints(map, GridUtil.collapse_consecutive_cells(GridUtil.px_points_to_cell_waypoints(pts)))
	_line_for(op_id).points = pts
	board.set_route(op_id, cells)
	route_committed.emit(op_id, cells)
	print("[PLAN] op %d route committed: %d waypoints, %d px baked" % [op_id, cells.size(), pts.size()])
	_exit_routing()


func _exit_routing() -> void:
	if _routing_token != null:
		_routing_token.set_routing_highlight(false)
	if loupe != null:
		loupe.hide_loupe()
	mode = Mode.OBSERVATION
	_routing_finger = -1
	_routing_token = null
	_raw_route = PackedVector2Array()
	_kept_route = PackedVector2Array()
	mode_changed.emit(mode)


func commit_tap_cell(op_id: int, start_cell: Vector2i, target_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if map == null:
		return cells
	cells = GridPathfinder.find_path(map, start_cell, target_cell)
	if cells.is_empty():
		return cells
	var pts := PackedVector2Array()
	for c in cells:
		pts.append(GridUtil.cell_center_px(c))
	_line_for(op_id).points = pts
	board.set_route(op_id, cells)
	route_committed.emit(op_id, cells)
	return cells


func _handle_tap(pos: Vector2) -> void:
	if not routing_enabled:
		return
	var world := _to_world(pos)
	var cell := GridUtil.px_to_cell(world)
	cell_tapped.emit(cell)


func _ensure_preview() -> void:
	if _preview == null and line_container != null:
		_preview = _make_line(3.0, PREVIEW_COLOR)


func show_route(op_id: int, pts: PackedVector2Array) -> void:
	_line_for(op_id).points = pts


func show_waits(op_id: int, waits: Dictionary) -> void:
	var line := _line_for(op_id)
	for marker in line.get_children():
		line.remove_child(marker)
		marker.queue_free()
	for cell in waits:
		var mark := Label.new()
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.text = String(waits[cell]).to_upper()
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.add_theme_font_size_override("font_size", 9)
		mark.add_theme_color_override("font_outline_color", Color.BLACK)
		mark.add_theme_constant_override("outline_size", 3)
		mark.position = GridUtil.cell_center_px(cell) - Vector2(9.0, 8.0)
		mark.size = Vector2(18.0, 16.0)
		line.add_child(mark)


func route_line(op_id: int) -> Line2D:
	return _route_lines.get(op_id, null)


func _line_for(op_id: int) -> Line2D:
	if _route_lines.has(op_id):
		return _route_lines[op_id]
	var color: Color = op_colors.get(op_id, COMMITTED_COLOR)
	color.a = 0.85
	var line := _make_line(2.0, color)
	_route_lines[op_id] = line
	return line


func _make_line(width: float, color: Color) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.antialiased = false
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line_container.add_child(line)
	return line


func _to_world(vp_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * vp_pos
