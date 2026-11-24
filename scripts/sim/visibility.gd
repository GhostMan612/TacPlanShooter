# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name Visibility
extends RefCounted


static func compute_polygon(observer: Vector2, segments: Array, eps: float = 0.00001) -> PackedVector2Array:
	var rays := []
	for s in segments:
		for v in s:
			var d: Vector2 = v - observer
			if d.length_squared() < 0.0001:
				continue
			var a := atan2(d.y, d.x)
			rays.append(a)
			rays.append(wrap_angle(a + eps))
			rays.append(wrap_angle(a - eps))
	rays.sort()
	var pts := PackedVector2Array()
	for ang in rays:
		var dir := Vector2(cos(ang), sin(ang))
		var best := -1.0
		for s in segments:
			var t := _ray_hit_t(observer, dir, s[0], s[1])
			if t > 0 and (best < 0 or t < best):
				best = t
		if best > 0:
			pts.append(observer + dir * best)
	return pts


static func wrap_angle(a: float) -> float:
	if a > PI:
		return a - TAU
	if a < -PI:
		return a + TAU
	return a


static func _ray_hit_t(o: Vector2, d: Vector2, a: Vector2, b: Vector2) -> float:
	var ba := b - a
	var det := d.cross(ba)
	if det == 0.0:
		return -1.0
	var w := a - o
	var t := w.cross(ba) / det
	var u := w.cross(d) / det
	if t > 0.0 and u >= -0.000001 and u <= 1.000001:
		return t
	return -1.0
