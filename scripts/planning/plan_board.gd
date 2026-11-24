# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name PlanBoard
extends RefCounted


const SQUAD_COLORS: Dictionary = {
	&"red": Color(0xEF, 0x44, 0x44),
	&"blue": Color(0x3B, 0x82, 0xF6),
	&"green": Color(0x22, 0xC5, 0x5E),
	&"gold": Color(0xF5, 0x9E, 0x0B),
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
