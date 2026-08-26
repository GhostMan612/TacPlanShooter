# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name PlanningController
extends Node

signal mode_changed(mode: int)
signal route_committed(op_id: int, waypoints: Array[Vector2i])

enum Mode { OBSERVATION, ROUTING }

const LONG_PRESS_SEC := 0.45
const TAP_MAX_SEC := 0.3
const SLOP_PX := 10.0
const SELECT_RADIUS_PX := 30.0

var camera: MissionCamera = null
var tokens: Array[OperativeToken] = []
var board := PlanBoard.new()
var line_container: Node2D = null
var mode := Mode.OBSERVATION

var _touches := {}
var _press_time := {}
var _press_origin := {}
var _long_fired := {}
var _routing_finger := -1
var _routing_token: OperativeToken = null
var _raw_route := PackedVector2Array()
var _preview: Line2D = null
var _pinch_base_dist := 0.0
var _pinch_base_zoom := 1.0


func _process(delta: float) -> void:
	var fired_now: Array = []
	for idx in _press_time.keys():
		_press_time[idx] += delta
		if bool(_long_fired.get(idx, false)):
			continue
		var origin: Vector2 = _press_origin[idx]
		var cur: Vector2 = _touches.get(idx, origin)
		if origin.distance_to(cur) >= SLOP_PX:
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
		var keys := _touches.keys()
		_pinch_base_dist = (_touches[keys[0]] as Vector2).distance_to(_touches[keys[1]] as Vector2)
		_pinch_base_zoom = camera.base_zoom() if camera != null else 1.0


func _on_release(idx: int, pos: Vector2) -> void:
	var dt: float = _press_time.get(idx, 999.0)
	var origin: Vector2 = _press_origin.get(idx, pos)
	var moved := origin.distance_to(pos) >= SLOP_PX
	var was_routing := idx == _routing_finger
	_touches.erase(idx)
	_press_time.erase(idx)
	_press_origin.erase(idx)
	_long_fired.erase(idx)
	if was_routing:
		_commit_route()
		return
	if mode == Mode.OBSERVATION and _touches.size() == 1:
		_pinch_base_dist = 0.0
	if mode == Mode.OBSERVATION and dt <= TAP_MAX_SEC and not moved and not bool(_long_fired.get(idx, false)):
		_handle_tap(pos)


func _on_drag(idx: int, pos: Vector2, relative: Vector2) -> void:
	if not _touches.has(idx):
		return
	_touches[idx] = pos
	if idx == _routing_finger and mode == Mode.ROUTING:
		_raw_route.append(_to_world(pos))
		var decimated := RouteSanitizer.decimate(_raw_route)
		_preview.points = RouteSanitizer.bake_smooth(decimated)
		return
	if mode != Mode.OBSERVATION:
		return
	if _touches.size() == 1:
		camera.pan_by(relative)
	elif _touches.size() == 2 and _pinch_base_dist > 0.0 and camera != null:
		var keys := _touches.keys()
		var d := (_touches[keys[0]] as Vector2).distance_to(_touches[keys[1]] as Vector2)
		camera.apply_uniform_zoom(_pinch_base_zoom * (d / _pinch_base_dist))


func _try_begin_routing(idx: int, vp_pos: Vector2) -> void:
	var world := _to_world(vp_pos)
	var best: OperativeToken = null
	var best_d := SELECT_RADIUS_PX
	for t in tokens:
		var d := t.position.distance_to(world)
		if d < best_d:
			best_d = d
			best = t
	if best == null:
		return
	_routing_finger = idx
	_routing_token = best
	best.set_selected(true)
	mode = Mode.ROUTING
	_raw_route = PackedVector2Array([best.position])
	_ensure_preview()
	_preview.points = PackedVector2Array([best.position])
	mode_changed.emit(mode)
	print("[PLAN] routing op %d" % best.op_id)


func _commit_route() -> void:
	var pts := RouteSanitizer.bake_smooth(RouteSanitizer.decimate(_raw_route))
	_preview.points = pts
	var cells := GridUtil.collapse_consecutive_cells(GridUtil.px_points_to_cell_waypoints(pts))
	board.set_route(_routing_token.op_id, cells)
	route_committed.emit(_routing_token.op_id, cells)
	print("[PLAN] op %d route committed: %d waypoints, %d px baked" % [_routing_token.op_id, cells.size(), pts.size()])
	_exit_routing()


func _exit_routing() -> void:
	if _routing_token != null:
		_routing_token.set_selected(false)
	mode = Mode.OBSERVATION
	_routing_finger = -1
	_routing_token = null
	_raw_route = PackedVector2Array()
	mode_changed.emit(mode)


func _handle_tap(pos: Vector2) -> void:
	print("[PLAN] tap cell %s (command menus arrive in M4)" % str(GridUtil.px_to_cell(_to_world(pos))))


func _ensure_preview() -> void:
	if _preview == null and line_container != null:
		_preview = Line2D.new()
		_preview.width = 3.0
		_preview.antialiased = false
		_preview.default_color = Color(0.25, 0.85, 1.0, 0.85)
		_preview.joint_mode = Line2D.LINE_JOINT_ROUND
		_preview.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_preview.end_cap_mode = Line2D.LINE_CAP_ROUND
		line_container.add_child(_preview)


func _to_world(vp_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * vp_pos
