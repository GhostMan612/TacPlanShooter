# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name TouchRaycaster3D
extends RefCounted


const CELL_UNITS: float = 1.5
const FLOOR_RISE: float = 3.2


static func screen_to_cell(camera: Camera3D, screen_pos: Vector2, floor: int, _viewport: Vector2) -> Vector2i:
	if camera == null:
		return Vector2i(-1, -1)
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.00001:
		return Vector2i(-1, -1)
	var plane_y := float(floor) * FLOOR_RISE
	var t := (plane_y - origin.y) / dir.y
	if t <= 0.0:
		return Vector2i(-1, -1)
	var hit := origin + dir * t
	var cell := Vector2i(int(floorf(hit.x / CELL_UNITS)), int(floorf(hit.z / CELL_UNITS)))
	return cell


static func cell_center(cell: Vector2i, floor: int) -> Vector3:
	return Vector3(float(cell.x) * CELL_UNITS + CELL_UNITS * 0.5, float(floor) * FLOOR_RISE, float(cell.y) * CELL_UNITS + CELL_UNITS * 0.5)
