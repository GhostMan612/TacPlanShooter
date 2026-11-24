# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name MissionGrading
extends RefCounted


const RP_OBJECTIVE := 50
const RP_ZERO_CASUALTIES := 25


func grade(world: SimWorld, completed: bool) -> Dictionary:
	var zero_casualties := true
	for o in world.operatives:
		if not o.is_alive():
			zero_casualties = false
	var rp := 0
	if completed:
		rp += RP_OBJECTIVE
	if zero_casualties:
		rp += RP_ZERO_CASUALTIES
	return {"rp": rp, "xp": rp}
