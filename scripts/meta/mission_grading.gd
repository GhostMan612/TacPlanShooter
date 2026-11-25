# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name MissionGrading
extends RefCounted


const RP_OBJECTIVE := 50
const RP_ZERO_CASUALTIES := 25


static func letter_for(completed: bool, zero_casualties: bool, halted: bool) -> String:
	if not completed:
		return "F"
	if zero_casualties and not halted:
		return "S"
	if zero_casualties or not halted:
		return "A"
	return "B"


func grade(world: SimWorld, completed: bool) -> Dictionary:
	var zero_casualties := true
	var speed_bonus := 0
	for o in world.operatives:
		if not o.is_alive():
			zero_casualties = false
		if o.speed_cells_per_sec() > 4.0:
			speed_bonus += 5
	var rp := 0
	if completed:
		rp += RP_OBJECTIVE
	if zero_casualties:
		rp += RP_ZERO_CASUALTIES
	rp += speed_bonus
	return {"rp": rp, "xp": rp}
