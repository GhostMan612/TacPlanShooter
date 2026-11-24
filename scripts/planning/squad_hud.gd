# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name SquadHud
extends Node2D


var world: SimWorld = null
var selected_op: int = -1


func tap_operative(op_id: int) -> void:
	selected_op = op_id


func _draw() -> void:
	if world == null:
		return
	for o in world.operatives:
		if not o.is_alive():
			continue
		var dot := Color(0.9, 0.9, 0.9)
		if o.health == &"wounded":
			dot = Color(1.0, 0.85, 0.2)
		elif o.health == &"kia":
			dot = Color(1.0, 0.2, 0.2)
		draw_circle(o.pos, 8.0, dot)
		if o.id == selected_op:
			draw_circle(o.pos, 4.0, Color.WHITE)
