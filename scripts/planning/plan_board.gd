# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name PlanBoard
extends RefCounted


const SQUAD_COLORS: Dictionary = {
	&"red": Color(0.937, 0.267, 0.267),
	&"blue": Color(0.231, 0.510, 0.965),
	&"green": Color(0.133, 0.773, 0.369),
	&"gold": Color(0.961, 0.620, 0.043),
}


var routes := {}


static func squad_color(squad: StringName) -> Color:
	return SQUAD_COLORS.get(squad, Color(0.5, 0.5, 0.5))


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
