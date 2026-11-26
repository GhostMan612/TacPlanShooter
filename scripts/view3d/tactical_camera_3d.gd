# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name TacticalCamera3D
extends Camera3D

const PITCHES: Array[float] = [88.0, 52.0, 20.0]

var tier: int = 1
var yaw_deg: float = 0.0
var target_yaw: float = 0.0
var focus_point: Vector3 = Vector3.ZERO
var distance: float = 52.0
var active: bool = false
var _current_pitch: float = -52.0
var _last_projection: int = -1


func _process(delta: float) -> void:
	if not active:
		return
	var k: float = 1.0 - exp(-9.0 * delta)
	var a0: float = deg_to_rad(yaw_deg)
	var a1: float = deg_to_rad(target_yaw)
	yaw_deg = rad_to_deg(lerp_angle(a0, a1, k))
	_current_pitch = lerpf(_current_pitch, -PITCHES[tier], k)
	_apply()


func on_resize(_size: Vector2) -> void:
	_apply()


func set_active(value: bool) -> void:
	active = value
	if value:
		make_current()
	_apply()


func focus(point: Vector3) -> void:
	focus_point = point


func cycle_pitch() -> void:
	tier = (tier + 1) % PITCHES.size()


func snap_yaw(direction: int) -> void:
	target_yaw = roundf(target_yaw / 90.0) * 90.0 + float(direction) * 90.0


func twist_by(delta_deg: float) -> void:
	target_yaw += delta_deg


func snap_nearest() -> void:
	target_yaw = roundf(target_yaw / 90.0) * 90.0


func _apply() -> void:
	var want_projection: int = Camera3D.PROJECTION_ORTHOGONAL if tier == 0 else Camera3D.PROJECTION_PERSPECTIVE
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
	var horizontal: float = cos(pitch_rad) * distance
	var offset := Vector3(sin(yaw_rad) * horizontal, sin(pitch_rad) * distance, cos(yaw_rad) * horizontal)
	global_position = focus_point + offset
	look_at(focus_point, Vector3.UP)
