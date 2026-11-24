# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name MissionGrader
extends RefCounted


static func grade(world: SimWorld) -> Dictionary:
	var completed := world.all_done()
	var zero_casualties := true
	for o in world.operatives:
		if not o.is_alive():
			zero_casualties = false
	return {
		"completed": completed,
		"zero_casualties": zero_casualties,
	}
