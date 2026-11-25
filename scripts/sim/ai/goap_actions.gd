# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name GoapActions
extends RefCounted

const F_TARGET_VISIBLE := 1 << 0
const F_LKP_KNOWN := 1 << 1
const F_IN_COVER := 1 << 2
const F_UNDER_SUPPRESSION := 1 << 3
const F_AMMO_LOW := 1 << 4
const F_HAS_FLASHBANG := 1 << 5
const F_HAS_FRAG := 1 << 6
const F_HAS_SMOKE := 1 << 7
const F_ALLY_SUPPRESSING := 1 << 8
const F_FLANK_OPEN := 1 << 9
const F_SPOTTED_BY_DRONE := 1 << 10
const F_HOSTAGE_NEAR := 1 << 11
const F_TARGET_IN_COVER := 1 << 12
const F_HAS_THROW_ANGLE := 1 << 13
const F_TARGET_FLUSHED := 1 << 14
const F_CALLOUT_SENT := 1 << 15
const F_AMMO_FULL := 1 << 16
const F_HEAR_BREACH := 1 << 17
const F_JAMMER_AVAILABLE := 1 << 18
const F_DRONE_HANDLED := 1 << 19
const F_AT_TACTICAL_CELL := 1 << 20
const F_PRE_AIMED := 1 << 21
const F_TARGET_ENGAGED := 1 << 22
const F_DRONE_SHOOTABLE := 1 << 23
const F_REPOSITIONED := 1 << 24
const F_BOUNDED := 1 << 25

const FACT_BITS := {
	"target_visible": F_TARGET_VISIBLE,
	"lkp_known": F_LKP_KNOWN,
	"in_cover": F_IN_COVER,
	"under_suppression": F_UNDER_SUPPRESSION,
	"ammo_low": F_AMMO_LOW,
	"has_flashbang": F_HAS_FLASHBANG,
	"has_frag": F_HAS_FRAG,
	"has_smoke": F_HAS_SMOKE,
	"ally_suppressing": F_ALLY_SUPPRESSING,
	"flank_open": F_FLANK_OPEN,
	"spotted_by_drone": F_SPOTTED_BY_DRONE,
	"hostage_near": F_HOSTAGE_NEAR,
	"target_in_cover": F_TARGET_IN_COVER,
	"has_throw_angle": F_HAS_THROW_ANGLE,
	"target_flushed": F_TARGET_FLUSHED,
	"callout_sent": F_CALLOUT_SENT,
	"ammo_full": F_AMMO_FULL,
	"hear_breach": F_HEAR_BREACH,
	"jammer_available": F_JAMMER_AVAILABLE,
	"drone_handled": F_DRONE_HANDLED,
	"at_tactical_cell": F_AT_TACTICAL_CELL,
	"pre_aimed": F_PRE_AIMED,
	"target_engaged": F_TARGET_ENGAGED,
	"drone_shootable": F_DRONE_SHOOTABLE,
	"repositioned": F_REPOSITIONED,
	"bounded": F_BOUNDED,
}


static func facts_to_mask(d: Dictionary) -> int:
	var mask: int = 0
	for k in FACT_BITS.keys():
		if bool(d.get(k, false)):
			mask |= int(FACT_BITS[k])
	return mask


static func build_catalog(allow_grenades: bool = true, allow_smoke: bool = true) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if allow_grenades:
		out.append(_act(&"MoveToThrowAngle", 2, F_LKP_KNOWN | F_TARGET_IN_COVER, F_HAS_THROW_ANGLE | F_AMMO_LOW, F_HAS_THROW_ANGLE, 0))
		out.append(_act(&"ThrowFragOrFlash", 2, F_HAS_THROW_ANGLE | F_HAS_FLASHBANG, 0, F_TARGET_FLUSHED, F_TARGET_IN_COVER | F_HAS_FLASHBANG))
		out.append(_act(&"ThrowFragOrFlash", 2, F_HAS_THROW_ANGLE | F_HAS_FRAG, F_HOSTAGE_NEAR, F_TARGET_FLUSHED, F_TARGET_IN_COVER | F_HAS_FRAG))
		out.append(_act(&"AdvanceOnStunned", 1, F_TARGET_FLUSHED, F_AMMO_LOW, F_AT_TACTICAL_CELL | F_TARGET_ENGAGED, 0))
	out.append(_act(&"SuppressLKP", 2, F_LKP_KNOWN, F_AMMO_LOW, F_ALLY_SUPPRESSING | F_TARGET_ENGAGED, 0))
	if allow_smoke:
		out.append(_act(&"DeploySmoke", 1, F_HAS_SMOKE | F_UNDER_SUPPRESSION, F_IN_COVER, F_FLANK_OPEN, F_HAS_SMOKE))
	out.append(_act(&"BoundCoverToCover", 1, F_LKP_KNOWN | F_FLANK_OPEN, F_AMMO_LOW, F_AT_TACTICAL_CELL | F_IN_COVER | F_BOUNDED, 0))
	out.append(_act(&"FlankEngage", 1, F_AT_TACTICAL_CELL | F_FLANK_OPEN | F_BOUNDED, F_AMMO_LOW, F_TARGET_ENGAGED, 0))
	out.append(_act(&"CalloutCoveringFire", 1, F_AMMO_LOW, F_CALLOUT_SENT, F_CALLOUT_SENT, 0))
	out.append(_act(&"StepBehindHardCover", 2, F_AMMO_LOW, F_IN_COVER, F_IN_COVER, 0))
	out.append(_act(&"Reload", 2, F_AMMO_LOW | F_IN_COVER, 0, F_AMMO_FULL, F_AMMO_LOW))
	out.append(_act(&"RePeek", 1, F_AMMO_FULL | F_IN_COVER, 0, F_PRE_AIMED, 0))
	out.append(_act(&"TriggerRFJammer", 1, F_SPOTTED_BY_DRONE | F_JAMMER_AVAILABLE, 0, F_DRONE_HANDLED, 0))
	out.append(_act(&"EngageDrone", 2, F_SPOTTED_BY_DRONE | F_DRONE_SHOOTABLE, F_AMMO_LOW, F_DRONE_HANDLED, 0))
	out.append(_act(&"BreakDroneLOS", 3, F_SPOTTED_BY_DRONE, F_DRONE_HANDLED, F_DRONE_HANDLED, 0))
	out.append(_act(&"RepositionCell", 1, F_SPOTTED_BY_DRONE | F_DRONE_HANDLED, 0, F_AT_TACTICAL_CELL | F_IN_COVER | F_REPOSITIONED, F_SPOTTED_BY_DRONE))
	out.append(_act(&"FallbackToCrossfireCell", 2, F_HEAR_BREACH, F_AT_TACTICAL_CELL, F_AT_TACTICAL_CELL | F_IN_COVER, 0))
	out.append(_act(&"PreAimFatalFunnel", 1, F_HEAR_BREACH | F_AT_TACTICAL_CELL, F_PRE_AIMED, F_PRE_AIMED, F_HEAR_BREACH))
	out.append(_act(&"EngageVisibleTarget", 1, F_TARGET_VISIBLE, F_TARGET_IN_COVER | F_AMMO_LOW | F_SPOTTED_BY_DRONE, F_TARGET_ENGAGED, 0))
	out.append(_act(&"TakeHardCover", 2, F_UNDER_SUPPRESSION, F_IN_COVER, F_IN_COVER, 0))
	return out


static func _act(p_name: StringName, p_cost: int, p_pre_pos: int, p_pre_neg: int, p_add: int, p_del: int) -> Dictionary:
	return {
		"name": p_name,
		"cost": p_cost,
		"pre_pos": p_pre_pos,
		"pre_neg": p_pre_neg,
		"add": p_add,
		"del": p_del,
	}
