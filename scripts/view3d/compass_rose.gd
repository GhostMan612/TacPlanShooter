# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name CompassRose
extends Control


var yaw_deg: float = 0.0


func _process(_delta: float) -> void:
	var cam := get_parent() as Camera3D
	if cam is TacticalCamera3D:
		var next_yaw: float = (cam as TacticalCamera3D).yaw_deg
		if absf(next_yaw - yaw_deg) > 0.1:
			yaw_deg = next_yaw
			queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.36
	draw_circle(c, r + 6.0, Color(0.04, 0.07, 0.11, 0.72))
	draw_arc(c, r + 6.0, 0.0, TAU, 32, Color(0.18, 0.83, 0.75, 0.8), 1.5)
	var letters := ["N", "E", "S", "W"]
	for i in range(4):
		var a := deg_to_rad(float(i * 90) - yaw_deg - 90.0)
		var p := c + Vector2(cos(a), sin(a)) * r
		var col := Color(1.0, 0.35, 0.25) if i == 0 else Color(0.82, 0.90, 0.98)
		draw_string(ThemeDB.fallback_font, p - Vector2(5.0, 5.0), letters[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
	draw_line(c, c + Vector2(0.0, -r * 0.7), Color(1.0, 0.35, 0.25, 0.9), 2.0)
