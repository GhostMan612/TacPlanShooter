# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name TacticalCamera3D
extends Camera3D


enum Tier { MAP, TACTICAL, EYE }

const PITCHES: Array[float] = [88.0, 52.0, 22.0]
const DISTANCES: Array[float] = [62.0, 42.0, 14.0]
const DAMP_SECONDS: float = 0.22
const MIN_PITCH := 18.0
const MAX_PITCH := 88.0
const MIN_DISTANCE := 8.0
const MAX_DISTANCE := 96.0


var tier: int = int(Tier.TACTICAL)
var yaw_deg: float = 0.0
var target_yaw: float = 0.0
var focus_point: Vector3 = Vector3.ZERO
var distance: float = 42.0
var active: bool = false
var bounds: Rect2 = Rect2(-80.0, -80.0, 180.0, 180.0)
var cutaway_material: ShaderMaterial = null

var _current_pitch: float = -52.0
var _current_distance: float = 42.0
var _pitch_override: float = -1.0
var _last_projection: int = -1
var _touches: Dictionary = {}
var _pinch_dist: float = 0.0
var _twist_deg: float = 0.0
var _two_y: float = 0.0
var _hud: CanvasLayer = null
var _hud_buttons: Dictionary = {}


func _ready() -> void:
	mount_hud()


func _process(delta: float) -> void:
	if not active:
		return
	var k: float = 1.0 - exp(-delta / DAMP_SECONDS)
	yaw_deg = rad_to_deg(lerp_angle(deg_to_rad(yaw_deg), deg_to_rad(target_yaw), k))
	var want_pitch := _pitch_override if _pitch_override >= 0.0 else PITCHES[clampi(tier, 0, 2)]
	_current_pitch = lerpf(_current_pitch, -want_pitch, k)
	_current_distance = lerpf(_current_distance, distance, k)
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touches[t.index] = t.position
			if _touches.size() == 2:
				_snapshot_gesture()
		else:
			_touches.erase(t.index)
			if _touches.size() < 2:
				snap_nearest()
				_pinch_dist = 0.0
		return
	if event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if not _touches.has(d.index):
			return
		var prev: Vector2 = _touches[d.index]
		_touches[d.index] = d.position
		if _touches.size() == 1:
			_pan(d.position - prev)
		elif _touches.size() >= 2:
			_gesture(d.position - prev)


func _snapshot_gesture() -> void:
	var pts := _touch_points()
	if pts.size() < 2:
		return
	var delta: Vector2 = pts[1] - pts[0]
	_pinch_dist = delta.length()
	_twist_deg = rad_to_deg(atan2(delta.y, delta.x))
	_two_y = (pts[0].y + pts[1].y) * 0.5


func _touch_points() -> Array:
	var out := []
	for k in _touches.keys():
		out.append(_touches[k])
	return out


func _pan(screen_delta: Vector2) -> void:
	var scale := _current_distance / 900.0
	focus_point.x = clampf(focus_point.x - screen_delta.x * scale, bounds.position.x, bounds.end.x)
	focus_point.z = clampf(focus_point.z + screen_delta.y * scale, bounds.position.y, bounds.end.y)


func _gesture(delta: Vector2) -> void:
	var pts := _touch_points()
	if pts.size() < 2:
		return
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[1]
	var span := (b - a).length()
	if _pinch_dist > 0.0 and span > 0.0:
		distance = clampf(distance * (_pinch_dist / span), MIN_DISTANCE, MAX_DISTANCE)
	_pinch_dist = span
	var mid_y := (a.y + b.y) * 0.5
	_pitch_override = clampf(_pitch_override if _pitch_override >= 0.0 else PITCHES[clampi(tier, 0, 2)], MIN_PITCH, MAX_PITCH) + (mid_y - _two_y) * 0.12
	_two_y = mid_y
	var twist := rad_to_deg(atan2(b.y - a.y, b.x - a.x))
	var d: float = fposmod(twist - _twist_deg + 180.0, 360.0) - 180.0
	target_yaw += d
	_twist_deg = twist


func mount_hud() -> void:
	if _hud != null:
		return
	_hud = CanvasLayer.new()
	_hud.name = "CameraControlHud"
	add_child(_hud)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.position = Vector2(-84.0, 280.0)
	_hud.add_child(box)
	_add_pill(box, "MAP", "MAP", int(Tier.MAP))
	_add_pill(box, "2.5D", "2.5D", int(Tier.TACTICAL))
	_add_pill(box, "EYE", "EYE", int(Tier.EYE))
	var left := _add_pill(box, "↺", "CCW", -1)
	var right := _add_pill(box, "↻", "CW", 1)
	_hud_buttons["CCW"] = left
	_hud_buttons["CW"] = right


func _add_pill(parent: Node, label: String, key: String, value: int) -> Button:
	var b := Button.new()
	b.name = "Pill_" + key
	b.text = label
	b.custom_minimum_size = Vector2(56.0, 56.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.10, 0.15, 0.82)
	sb.set_corner_radius_all(12)
	sb.border_color = Color(0.18, 0.83, 0.75, 0.9)
	sb.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.pressed.connect(_on_pill.bind(key, value))
	parent.add_child(b)
	return b


func _on_pill(key: String, value: int) -> void:
	if key == "CCW" or key == "CW":
		snap_yaw(value)
		return
	_pitch_override = -1.0
	tier = clampi(value, 0, 2)
	distance = DISTANCES[tier]


func on_resize(_size: Vector2) -> void:
	_apply()


func set_active(value: bool) -> void:
	active = value
	if value:
		make_current()
	_apply()


func focus(point: Vector3) -> void:
	focus_point = point


func set_tier(value: int) -> void:
	_on_pill("TIER", value)


func cycle_pitch() -> void:
	_on_pill("TIER", (tier + 1) % PITCHES.size())


func snap_yaw(direction: int) -> void:
	target_yaw = roundf(target_yaw / 90.0) * 90.0 + float(direction) * 90.0


func twist_by(delta_deg: float) -> void:
	target_yaw += delta_deg


func snap_nearest() -> void:
	target_yaw = roundf(target_yaw / 90.0) * 90.0


func _apply() -> void:
	var want_projection: int = Camera3D.PROJECTION_ORTHOGONAL if tier == int(Tier.MAP) else Camera3D.PROJECTION_PERSPECTIVE
	if want_projection != _last_projection:
		projection = want_projection
		_last_projection = want_projection
	if projection == Camera3D.PROJECTION_ORTHOGONAL:
		size = 34.0
	else:
		fov = 55.0
	near = 0.05
	var pitch_rad: float = deg_to_rad(-_current_pitch)
	var yaw_rad: float = deg_to_rad(yaw_deg)
	var horizontal: float = cos(pitch_rad) * _current_distance
	var offset := Vector3(sin(yaw_rad) * horizontal, sin(pitch_rad) * _current_distance, cos(yaw_rad) * horizontal)
	global_position = focus_point + offset
	look_at(focus_point, Vector3.UP)
	if cutaway_material != null:
		cutaway_material.set_shader_parameter("focus_pos", focus_point)
