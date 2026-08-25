# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name PlanBoard
extends RefCounted

var routes := {}


func set_route(op_id: int, cells: Array[Vector2i]) -> void:
	routes[op_id] = cells


func get_route(op_id: int) -> Array[Vector2i]:
	if routes.has(op_id):
		return routes[op_id]
	return []


func clear_route(op_id: int) -> void:
	routes.erase(op_id)


func has_route(op_id: int) -> bool:
	return routes.has(op_id)
