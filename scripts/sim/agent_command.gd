# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name AgentCommand
extends Resource

enum CommandType { MOVE_TO_CELL, SET_STANCE, WAIT_GO_CODE, PERFORM_ACTION, SET_FIELD_OF_FIRE, SET_MODE, USE_STAIRS }
enum ActionKind { NONE, FLASHBANG, FRAG, TEAR_GAS, BREACH_CHARGE }

@export var operative_id: int = -1
@export var sequence_index: int = -1
@export var command_type: CommandType = CommandType.MOVE_TO_CELL
@export var target_cell: Vector2i = Vector2i.ZERO
@export var target_floor: int = 0
@export var bearing_deg: int = 0
@export var action_kind: ActionKind = ActionKind.NONE
@export var go_code: StringName = &""
@export var stance_name: StringName = &"normal"
@export var mode_name: StringName = &""


func to_dict() -> Dictionary:
	return {
		"operative_id": operative_id,
		"sequence_index": sequence_index,
		"command_type": int(command_type),
		"target_cell_x": target_cell.x,
		"target_cell_y": target_cell.y,
		"target_floor": target_floor,
		"bearing_deg": bearing_deg,
		"action_kind": int(action_kind),
		"go_code": String(go_code),
		"stance_name": String(stance_name),
		"mode_name": String(mode_name),
	}


static func from_dict(d: Dictionary) -> AgentCommand:
	var c := AgentCommand.new()
	c.operative_id = int(d.get("operative_id", -1))
	c.sequence_index = int(d.get("sequence_index", -1))
	c.command_type = int(d.get("command_type", 0)) as CommandType
	c.target_cell = Vector2i(int(d.get("target_cell_x", 0)), int(d.get("target_cell_y", 0)))
	c.target_floor = int(d.get("target_floor", 0))
	c.bearing_deg = int(d.get("bearing_deg", 0))
	c.action_kind = int(d.get("action_kind", 0)) as ActionKind
	c.go_code = StringName(String(d.get("go_code", "")))
	c.stance_name = StringName(String(d.get("stance_name", "normal")))
	c.mode_name = StringName(String(d.get("mode_name", "")))
	return c
