# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name ExecutionHud
extends Control


var world: SimWorld = null
var tapin_controller: TapInController = null


func refresh() -> void:
	pass


func touch_operative(op_id: int) -> void:
	if tapin_controller != null:
		tapin_controller.op_id = op_id


func draw_health_dots() -> void:
	if world == null:
		return
	var x := 16.0
	for o in world.operatives:
		var color := Color(0.6, 0.6, 0.6)
		if o.is_alive():
			color = Color(0.3, 0.85, 0.3) if o.health != &"wounded" else Color(1.0, 0.8, 0.2)
		draw_rect(Rect2(Vector2(x, 8.0), Vector2(10.0, 10.0)), color)
		x += 20.0
