# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name OverrideCommand
extends Resource


@export var tick: int = 0
@export var op_id: int = -1
@export var move_dir: Vector2 = Vector2.ZERO
@export var aim_deg: float = 0.0
@export var fire_pressed: bool = false
@export var use_slot: bool = false


func to_dict() -> Dictionary:
	return {
		"tick": tick,
		"op_id": op_id,
		"move_dir_x": move_dir.x,
		"move_dir_y": move_dir.y,
		"aim_deg": aim_deg,
		"fire_pressed": fire_pressed,
		"use_slot": use_slot,
	}


static func from_dict(d: Dictionary) -> OverrideCommand:
	var c := OverrideCommand.new()
	c.tick = int(d.get("tick", 0))
	c.op_id = int(d.get("op_id", -1))
	c.move_dir = Vector2(float(d.get("move_dir_x", 0.0)), float(d.get("move_dir_y", 0.0)))
	c.aim_deg = float(d.get("aim_deg", 0.0))
	c.fire_pressed = bool(d.get("fire_pressed", false))
	c.use_slot = bool(d.get("use_slot", false))
	return c
