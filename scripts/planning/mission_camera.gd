# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name MissionCamera
extends Camera2D

const MIN_ZOOM := 1.0
const MAX_ZOOM := 8.0

var _viewport_px := Vector2(1080, 1920)


func configure_for_map(map_px: Vector2, viewport_px: Vector2, padding := 48.0) -> void:
	_viewport_px = viewport_px
	limit_left = -int(padding)
	limit_top = -int(padding)
	limit_right = int(map_px.x + padding)
	limit_bottom = int(map_px.y + padding)
	position = map_px / 2.0
	var fit := minf(viewport_px.x / map_px.x, viewport_px.y / map_px.y)
	zoom = Vector2.ONE * clampf(fit * 0.92, MIN_ZOOM, MAX_ZOOM)
	clamp_to_limits()


func set_viewport_size(viewport_px: Vector2) -> void:
	_viewport_px = viewport_px
	clamp_to_limits()


func pan_by(screen_delta: Vector2) -> void:
	position -= screen_delta / zoom.x
	clamp_to_limits()


func apply_uniform_zoom(target: float) -> void:
	zoom = Vector2.ONE * clampf(target, MIN_ZOOM, MAX_ZOOM)
	clamp_to_limits()


func zoom_about(target: float, screen_point: Vector2) -> void:
	var offset_px := screen_point - _viewport_px * 0.5
	var anchor := position + offset_px / zoom.x
	zoom = Vector2.ONE * clampf(target, MIN_ZOOM, MAX_ZOOM)
	position = anchor - offset_px / zoom.x
	clamp_to_limits()


func base_zoom() -> float:
	return zoom.x


func clamp_to_limits() -> void:
	var half := _viewport_px * 0.5 / zoom.x
	position = Vector2(
		_clamp_axis(position.x, float(limit_left), float(limit_right), half.x),
		_clamp_axis(position.y, float(limit_top), float(limit_bottom), half.y)
	)


static func _clamp_axis(v: float, lo: float, hi: float, half: float) -> float:
	if hi - lo <= half * 2.0:
		return (lo + hi) * 0.5
	return clampf(v, lo + half, hi - half)
