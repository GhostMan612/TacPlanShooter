# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name MissionCamera
extends Camera2D

const MIN_ZOOM := 1.0
const MAX_ZOOM := 8.0


func configure_for_map(map_px: Vector2, viewport_px: Vector2, padding := 48.0) -> void:
	limit_left = -int(padding)
	limit_top = -int(padding)
	limit_right = int(map_px.x + padding)
	limit_bottom = int(map_px.y + padding)
	position = map_px / 2.0
	var fit := minf(viewport_px.x / map_px.x, viewport_px.y / map_px.y)
	zoom = Vector2.ONE * clampf(fit * 0.92, MIN_ZOOM, MAX_ZOOM)


func pan_by(screen_delta: Vector2) -> void:
	position -= screen_delta / zoom.x


func apply_uniform_zoom(target: float) -> void:
	zoom = Vector2.ONE * clampf(target, MIN_ZOOM, MAX_ZOOM)


func base_zoom() -> float:
	return zoom.x
