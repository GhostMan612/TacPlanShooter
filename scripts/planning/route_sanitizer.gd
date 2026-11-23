# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name RouteSanitizer
extends Object

const MIN_POINT_DIST_PX := 12.0
const BAKE_INTERVAL_PX := 8.0
const TENSION := 1.0 / 6.0


static func decimate(points: PackedVector2Array, min_dist := MIN_POINT_DIST_PX) -> PackedVector2Array:
	var out := PackedVector2Array()
	if points.size() == 0:
		return out
	out.append(points[0])
	for i in range(1, points.size()):
		if out[out.size() - 1].distance_to(points[i]) >= min_dist:
			out.append(points[i])
	var last: Vector2 = points[points.size() - 1]
	var tail := out.size() - 1
	if out[tail] != last:
		if tail >= 1:
			out[tail] = last
		else:
			out.append(last)
	return out


static func bake_smooth(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var curve := Curve2D.new()
	curve.bake_interval = BAKE_INTERVAL_PX
	var n := points.size()
	for i in range(n):
		var prev: Vector2 = points[maxi(i - 1, 0)]
		var next: Vector2 = points[mini(i + 1, n - 1)]
		var tangent: Vector2 = (next - prev) * TENSION
		curve.add_point(points[i], -tangent, tangent)
	var baked := curve.get_baked_points()
	if baked.size() == 0:
		return points
	var last: Vector2 = points[n - 1]
	if baked[baked.size() - 1].distance_to(last) > 0.001:
		baked.append(last)
	return baked
