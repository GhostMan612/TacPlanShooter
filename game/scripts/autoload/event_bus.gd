# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
extends Node

signal phase_changed(new_phase: int)
signal plan_committed()
signal tick_advanced(tick: int)
signal go_code_issued(code: StringName)
signal operative_halted(operative_id: int, at_cell: Vector2i)
signal operative_damaged(operative_id: int, remaining_hp: int)
signal breach_detonated(world_pos: Vector2)
