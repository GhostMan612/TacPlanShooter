# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name MissionSnapshot
extends RefCounted

var data := {}
var captured_tick := -1


static func capture(world: SimWorld) -> MissionSnapshot:
	var s := MissionSnapshot.new()
	s.data = world.snapshot_data()
	s.captured_tick = world.tick
	return s


func restore_into(world: SimWorld) -> void:
	world.restore_from_data(data)
