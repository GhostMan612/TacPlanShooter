# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name TapInController
extends Node2D


var world: SimWorld = null
var lockstep: LockstepSession = null
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


func ingest_cell_target(op: SimOperative, cell: Vector2i) -> bool:
	if world == null or op == null or not op.is_alive():
		return false
	if world.tapin_points <= 0 or world.tapin_player_cooldown > 0:
		return false
	if int(world.tapin_unit_cooldowns.get(op.id, 0)) > 0:
		return false
	op_id = op.id
	var center := Vector2(cell) + Vector2(0.5, 0.5)
	var aim := op.facing_deg if cell == GridUtil.cell_of(op.pos) else CombatSystem.angle_to(op.pos, center)
	if aim == 0.0:
		aim = 0.001
	var target_vec := Vector2(float(cell.x), float(cell.y))
	if lockstep != null and lockstep.session_active:
		lockstep.queue_input(op.id, target_vec, aim, false, true)
	else:
		ingest(target_vec, aim, false, true)
	return true


func release_ai() -> void:
	op_id = -1
