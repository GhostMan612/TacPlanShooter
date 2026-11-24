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
