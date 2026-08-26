# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name RouteSanitizer
extends Object

const MIN_POINT_DIST_PX := 12.0
const BAKE_INTERVAL_PX := 8.0


static func decimate(points: PackedVector2Array, min_dist := MIN_POINT_DIST_PX) -> PackedVector2Array:
	var out := PackedVector2Array()
	if points.size() == 0:
		return out
	out.append(points[0])
	for i in range(1, points.size()):
		if out[out.size() - 1].distance_to(points[i]) >= min_dist:
			out.append(points[i])
	return out


static func bake_smooth(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var curve := Curve2D.new()
	curve.bake_interval = BAKE_INTERVAL_PX
	for p in points:
		curve.add_point(p)
	return curve.get_baked_points()
