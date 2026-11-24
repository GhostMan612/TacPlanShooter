# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name FriendlyReflexAi
extends RefCounted


enum RoeMode { ENGAGE, ADVANCE, ESCORT }


var mode := int(RoeMode.ENGAGE)
var suppression := 0


func set_roe(m: int) -> void:
	mode = m


func snap_check(hostage_cells: Array) -> bool:
	return suppression >= 85


func lof_clear(hostage_cells: Array[Vector2i], ally: Vector2, target: Vector2) -> bool:
	var d := target - ally
	if d.length_squared() < 0.0001:
		return true
	for c in hostage_cells:
		var rect := GridUtil.cell_rect_px(c)
		var corners := [
			rect.position,
			Vector2(rect.position.x + rect.size.x, rect.position.y),
			Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y),
			Vector2(rect.position.x, rect.position.y + rect.size.y),
		]
		for i in range(4):
			if Geometry2D.segment_intersects_segment(ally, target, corners[i], corners[(i + 1) % 4]):
				return false
	return true
