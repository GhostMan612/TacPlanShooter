# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name SquadHud
extends Control


var world: SimWorld = null
var selected_op: int = -1


func _ready() -> void:
	custom_minimum_size = Vector2(get_viewport_rect().size.x, 120)
	position = Vector2(0, get_viewport_rect().size.y - 120)


func touch_operative(op_id: int) -> void:
	selected_op = op_id
