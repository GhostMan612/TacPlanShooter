# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name CommandQueue
extends RefCounted

var operative_id: int = -1
var commands: Array[AgentCommand] = []
var cursor: int = 0


func _init(p_operative_id: int = -1) -> void:
	operative_id = p_operative_id


func reset(p_commands: Array[AgentCommand]) -> void:
	commands = p_commands.duplicate()
	cursor = 0


func enqueue(c: AgentCommand) -> void:
	c.sequence_index = commands.size()
	commands.append(c)


func peek_next() -> AgentCommand:
	if cursor >= commands.size():
		return null
	return commands[cursor]


func advance_cursor() -> void:
	cursor += 1


func is_complete() -> bool:
	return cursor >= commands.size()


func to_dict() -> Dictionary:
	var arr: Array = []
	for c in commands:
		arr.append(c.to_dict())
	return {
		"operative_id": operative_id,
		"cursor": cursor,
		"commands": arr,
	}


static func from_dict(d: Dictionary) -> CommandQueue:
	var q := CommandQueue.new(int(d.get("operative_id", -1)))
	q.cursor = int(d.get("cursor", 0))
	var arr: Array = d.get("commands", [])
	for cd in arr:
		q.commands.append(AgentCommand.from_dict(cd))
	return q
