# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name SquadConfig
extends RefCounted


const SQUADS: Array[StringName] = [&"red", &"blue", &"green", &"gold"]


var _members: Dictionary = {}
var _leader: Dictionary = {}


func add_member(squad: StringName, op_id: int) -> void:
	var arr: Array = _members.get(squad, [])
	if not arr.has(op_id):
		arr.append(op_id)
		_members[squad] = arr
		if not _leader.has(squad):
			_leader[squad] = op_id


func members(squad: StringName) -> Array:
	var arr: Array = _members.get(squad, [])
	return arr


func is_leader(squad: StringName, op_id: int) -> bool:
	return _leader.get(squad, -1) == op_id


func promote(squad: StringName, op_id: int) -> void:
	if members(squad).has(op_id):
		_leader[squad] = op_id


func leadership_modifier(squad: StringName) -> float:
	return 1.0


func clear() -> void:
	_members.clear()
	_leader.clear()
