# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name EnemyAi
extends RefCounted

enum State { IDLE_GUARD, PATROL, INVESTIGATE_LKP, HOLD_AMBUSH, SUPPRESS_LKP, FLANK_ROUTE, TAKE_COVER, STUNNED, FALLBACK_RALLY, HOSTAGE_COERCE, SURRENDER }

const RELOAD_DURATION_TICKS := 36
const LOW_AMMO_THRESHOLD := 3

var state := int(State.IDLE_GUARD)
var suppression := 0
var morale := 50
var archetype: StringName = &"patrol_sentry"
var doctrine: int = 1
var mag_size: int = 30
var ammo: int = 30
var reload_ticks_left: int = 0
var stun_ticks: int = 0
var grenade_cooldown: int = 0
var has_flashbang: bool = false
var has_frag: bool = false
var has_smoke: bool = false
var goap_goal: StringName = &""
var goap_plan: Array[StringName] = []
var goap_index: int = 0
var target_cell: Vector2i = Vector2i(-1, -1)
var peek_cell: Vector2i = Vector2i(-1, -1)
var spotted_by_drone_id: int = -1
var spotted_cell: Vector2i = Vector2i(-1, -1)
var heard_breach_cell: Vector2i = Vector2i(-1, -1)
var ally_suppressing: bool = false
var bound_goal_cell: Vector2i = Vector2i(-1, -1)
var last_callout_target: int = -1


func configure(p_archetype: StringName, p_doctrine: int = 1) -> void:
	archetype = p_archetype if not String(p_archetype).is_empty() else &"patrol_sentry"
	doctrine = p_doctrine
	if archetype == &"heavy_gunner":
		mag_size = 60
	elif archetype == &"room_anchor" or archetype == &"tactical_flanker":
		mag_size = 30
	else:
		mag_size = 24
	ammo = mag_size
	var allow_kit: bool = p_doctrine != 0
	has_flashbang = allow_kit and (archetype == &"tactical_flanker" or archetype == &"room_anchor" or archetype == &"heavy_gunner" or archetype == &"hostage_guard" or archetype == &"tech_jammer")
	has_frag = allow_kit and (archetype == &"tactical_flanker" or archetype == &"room_anchor")
	has_smoke = allow_kit and (archetype == &"tech_jammer" or archetype == &"tactical_flanker")


func transition(s: int) -> void:
	state = s


func suppress_near_miss(ticks: int) -> void:
	suppression += ticks


func suppress_tick_down() -> void:
	if suppression > 0:
		suppression -= 1


func surrender_check() -> bool:
	return state == int(State.SUPPRESS_LKP) and suppression >= 80 and morale <= 20


func is_stunned() -> bool:
	return state == int(State.STUNNED)


func ai_tick() -> void:
	if surrender_check():
		transition(int(State.SURRENDER))
	elif suppression >= 80:
		transition(int(State.SUPPRESS_LKP))
	elif state == int(State.STUNNED) and suppression > 0:
		transition(int(State.TAKE_COVER))
	elif state == int(State.SUPPRESS_LKP):
		transition(int(State.INVESTIGATE_LKP))
	elif state == int(State.IDLE_GUARD) and suppression > 0:
		transition(int(State.HOLD_AMBUSH))
	elif state == int(State.HOLD_AMBUSH) and suppression < 10:
		transition(int(State.IDLE_GUARD))


func to_dict() -> Dictionary:
	var plan_arr: Array = []
	for step_name in goap_plan:
		plan_arr.append(String(step_name))
	return {
		"state": state,
		"suppression": suppression,
		"morale": morale,
		"archetype": String(archetype),
		"doctrine": doctrine,
		"mag_size": mag_size,
		"ammo": ammo,
		"reload_ticks_left": reload_ticks_left,
		"stun_ticks": stun_ticks,
		"grenade_cooldown": grenade_cooldown,
		"has_flashbang": has_flashbang,
		"has_frag": has_frag,
		"has_smoke": has_smoke,
		"goap_goal": String(goap_goal),
		"goap_plan": plan_arr,
		"goap_index": goap_index,
		"tcx": target_cell.x,
		"tcy": target_cell.y,
		"pcx": peek_cell.x,
		"pcy": peek_cell.y,
		"drone_id": spotted_by_drone_id,
		"scx": spotted_cell.x,
		"scy": spotted_cell.y,
		"hcx": heard_breach_cell.x,
		"hcy": heard_breach_cell.y,
		"ally_sup": ally_suppressing,
		"bcx": bound_goal_cell.x,
		"bcy": bound_goal_cell.y,
		"last_ct": last_callout_target,
	}


static func from_dict(d: Dictionary) -> EnemyAi:
	var e := EnemyAi.new()
	e.state = int(d.get("state", int(State.IDLE_GUARD)))
	e.suppression = int(d.get("suppression", 0))
	e.morale = int(d.get("morale", 50))
	e.archetype = StringName(String(d.get("archetype", "patrol_sentry")))
	e.doctrine = int(d.get("doctrine", 1))
	e.mag_size = int(d.get("mag_size", 30))
	e.ammo = int(d.get("ammo", 30))
	e.reload_ticks_left = int(d.get("reload_ticks_left", 0))
	e.stun_ticks = int(d.get("stun_ticks", 0))
	e.grenade_cooldown = int(d.get("grenade_cooldown", 0))
	e.has_flashbang = bool(d.get("has_flashbang", false))
	e.has_frag = bool(d.get("has_frag", false))
	e.has_smoke = bool(d.get("has_smoke", false))
	e.goap_goal = StringName(String(d.get("goap_goal", "")))
	for s in d.get("goap_plan", []):
		e.goap_plan.append(StringName(String(s)))
	e.goap_index = int(d.get("goap_index", 0))
	e.target_cell = Vector2i(int(d.get("tcx", -1)), int(d.get("tcy", -1)))
	e.peek_cell = Vector2i(int(d.get("pcx", -1)), int(d.get("pcy", -1)))
	e.spotted_by_drone_id = int(d.get("drone_id", -1))
	e.spotted_cell = Vector2i(int(d.get("scx", -1)), int(d.get("scy", -1)))
	e.heard_breach_cell = Vector2i(int(d.get("hcx", -1)), int(d.get("hcy", -1)))
	e.ally_suppressing = bool(d.get("ally_sup", false))
	e.bound_goal_cell = Vector2i(int(d.get("bcx", -1)), int(d.get("bcy", -1)))
	e.last_callout_target = int(d.get("last_ct", -1))
	return e
