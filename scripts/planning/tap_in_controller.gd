# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name TapInController
extends Node2D


var world: SimWorld = null
var op_id: int = -1


func ingest(move_dir: Vector2, aim_deg: float, fire_pressed: bool, use_slot: bool) -> void:
	if world == null or op_id < 0:
		return
	var oc := OverrideCommand.new()
	oc.tick = world.tick + 1
	oc.op_id = op_id
	oc.move_dir = move_dir
	oc.aim_deg = aim_deg
	oc.fire_pressed = fire_pressed
	oc.use_slot = use_slot
	world.apply_override(oc)


func release_ai() -> void:
	op_id = -1
