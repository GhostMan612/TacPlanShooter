# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name CombatSystem
extends RefCounted


const ENGAGE_RANGE_CELLS := 10.0
const ENGAGE_HALF_ANGLE_DEG := 60.0
const FRIENDLY_REACTION_TICKS := 12
const FIRE_INTERVAL_TICKS := 12
const SUPPRESS_TICKS := 45
const ENEMY_MORALE_HIT := 30
const HIT_DAMAGE_SCALE := 10
const WOUNDED_HP := 50
const SUPPRESSED_ACCURACY_PENALTY := 0.25
const RANGE_ACCURACY_PENALTY := 0.03
const MIN_ACCURACY := 0.05
const MAX_ACCURACY := 0.95
const LOS_EPS := 0.000001
const FRIENDLY_CALIBER := &"5.56"
const ENEMY_CALIBERS := {
	&"patrol_sentry": &"9mm",
	&"room_anchor": &"5.56",
	&"tactical_flanker": &"5.56",
	&"heavy_gunner": &"7.62",
	&"tech_jammer": &"9mm",
	&"hostage_guard": &"9mm",
}
const ARMOR_KEYS := {
	&"light": &"light_iia",
	&"medium": &"medium_ii",
	&"heavy": &"heavy_iii_iv",
	&"shield": &"shield",
}
const STANCE_ACCURACY := {
	&"cautious": 0.75,
	&"normal": 0.6,
	&"blitz": 0.4,
}


var fire_cooldowns := {}
var sight := {}
var calibers := {}
var reactions := {}


static func armor_key(armor_class: StringName) -> StringName:
	return StringName(ARMOR_KEYS.get(armor_class, armor_class))


static func hit_damage(caliber: StringName, armor_class: StringName) -> int:
	return BallisticsSuppression.new().damage_for(caliber, armor_key(armor_class)) * HIT_DAMAGE_SCALE


static func angle_to(from: Vector2, to: Vector2) -> float:
	return rad_to_deg((to - from).angle())


static func angle_diff(a: float, b: float) -> float:
	return fposmod(a - b + 180.0, 360.0) - 180.0


static func accuracy(stance: StringName, distance: float, suppressed: bool) -> float:
	var acc := float(STANCE_ACCURACY.get(stance, 0.6)) - RANGE_ACCURACY_PENALTY * distance
	if suppressed:
		acc -= SUPPRESSED_ACCURACY_PENALTY
	return clampf(acc, MIN_ACCURACY, MAX_ACCURACY)


static func line_clear(a: Vector2, b: Vector2, segs: Array) -> bool:
	var d := b - a
	for s in segs:
		var t := Visibility._ray_hit_t(a, d, s[0], s[1])
		if t > LOS_EPS and t < 1.0 - LOS_EPS:
			return false
	return true


func register_enemy(id: int, archetype: StringName) -> void:
	calibers[id] = StringName(ENEMY_CALIBERS.get(archetype, &"9mm"))
	reactions[id] = int(AiArchetypes.by_name(archetype)["reaction_ticks"])


func caliber_of(id: int) -> StringName:
	return StringName(calibers.get(id, FRIENDLY_CALIBER))


func reaction_of(id: int) -> int:
	return int(reactions.get(id, FRIENDLY_REACTION_TICKS))


func actors(world: SimWorld) -> Array[SimOperative]:
	var out: Array[SimOperative] = []
	for o in world.operatives:
		out.append(o)
	var ids: Array = world.enemy_actors.keys()
	ids.sort()
	for id in ids:
		out.append(world.enemy_actors[id])
	return out


func can_fire(world: SimWorld, o: SimOperative) -> bool:
	if not o.is_alive():
		return false
	if world.ai.enemies.has(o.id):
		var brain: EnemyAi = world.ai.enemies[o.id]
		if brain.is_stunned() or brain.state == int(EnemyAi.State.SURRENDER):
			return false
	return true


func pick_target(shooter: SimOperative, all: Array[SimOperative], world: SimWorld, segs_box: Array) -> SimOperative:
	var best: SimOperative = null
	var best_d := INF
	for t in all:
		if t.faction_id == shooter.faction_id or not t.is_alive():
			continue
		var d := shooter.pos.distance_to(t.pos)
		if d > ENGAGE_RANGE_CELLS:
			continue
		if absf(angle_diff(angle_to(shooter.pos, t.pos), shooter.facing_deg)) > ENGAGE_HALF_ANGLE_DEG:
			continue
		if segs_box.is_empty():
			segs_box.append(world.map.get_wall_segments())
		if not line_clear(shooter.pos, t.pos, segs_box[0]):
			continue
		if d < best_d or (d == best_d and best != null and t.id < best.id):
			best = t
			best_d = d
	return best


func resolve(world: SimWorld) -> void:
	for id in fire_cooldowns.keys():
		var left := int(fire_cooldowns[id]) - 1
		if left <= 0:
			fire_cooldowns.erase(id)
		else:
			fire_cooldowns[id] = left
	for id in world.ballistics.suppression.keys():
		var s := int(world.ballistics.suppression[id]) - 1
		if s <= 0:
			world.ballistics.suppression.erase(id)
		else:
			world.ballistics.suppression[id] = s
	var all := actors(world)
	var segs_box := []
	for shooter in all:
		if not can_fire(world, shooter):
			sight.erase(shooter.id)
			continue
		var target := pick_target(shooter, all, world, segs_box)
		if target == null:
			sight.erase(shooter.id)
			continue
		var seen: Dictionary = sight.get(shooter.id, {})
		if seen.is_empty() or int(seen["target"]) != target.id:
			sight[shooter.id] = {"target": target.id, "since": world.tick}
			continue
		if world.tick - int(seen["since"]) < reaction_of(shooter.id):
			continue
		if fire_cooldowns.has(shooter.id):
			continue
		_fire(world, shooter, target)


func _fire(world: SimWorld, shooter: SimOperative, target: SimOperative) -> void:
	fire_cooldowns[shooter.id] = FIRE_INTERVAL_TICKS
	var dist := shooter.pos.distance_to(target.pos)
	if shooter.faction_id != 0:
		shooter.facing_deg = angle_to(shooter.pos, target.pos)
	var acc := accuracy(shooter.stance, dist, world.ballistics.suppressed_ticks(shooter.id) > 0)
	var hit := world.rng.randf() < acc
	world.sound_event(GridUtil.cell_of(shooter.pos), &"gunshot_unsuppressed")
	world.ballistics.apply_suppression(target.id, maxi(world.ballistics.suppressed_ticks(target.id), SUPPRESS_TICKS))
	if world.ai.enemies.has(target.id):
		var brain: EnemyAi = world.ai.enemies[target.id]
		brain.suppress_near_miss(SUPPRESS_TICKS)
		target.facing_deg = angle_to(target.pos, shooter.pos)
	var dmg := hit_damage(caliber_of(shooter.id), target.armor_class) if hit else 0
	world.journal.append({"t": world.tick, "ev": &"shot", "op": shooter.id, "target": target.id, "hit": hit, "dmg": dmg})
	if not hit:
		return
	target.hp = maxi(target.hp - dmg, 0)
	if world.ai.enemies.has(target.id):
		var hurt: EnemyAi = world.ai.enemies[target.id]
		hurt.morale = maxi(hurt.morale - ENEMY_MORALE_HIT, 0)
	if target.hp == 0:
		target.health = &"kia"
		target.active_path = PackedVector2Array()
		world.journal.append({"t": world.tick, "ev": &"kia", "op": target.id, "by": shooter.id})
	elif target.hp <= WOUNDED_HP:
		target.health = &"wounded"


func to_dict() -> Dictionary:
	var sight_rows: Array = []
	var ids: Array = sight.keys()
	ids.sort()
	for id in ids:
		var s: Dictionary = sight[id]
		sight_rows.append([int(id), int(s["target"]), int(s["since"])])
	var cal_rows: Array = []
	var cal_ids: Array = calibers.keys()
	cal_ids.sort()
	for id in cal_ids:
		cal_rows.append([int(id), String(calibers[id]), int(reactions.get(id, FRIENDLY_REACTION_TICKS))])
	var cd_rows: Array = []
	var cd_ids: Array = fire_cooldowns.keys()
	cd_ids.sort()
	for id in cd_ids:
		cd_rows.append([int(id), int(fire_cooldowns[id])])
	return {"sight": sight_rows, "calibers": cal_rows, "cooldowns": cd_rows}


static func from_dict(d: Dictionary) -> CombatSystem:
	var c := CombatSystem.new()
	for row in d.get("sight", []):
		c.sight[int(row[0])] = {"target": int(row[1]), "since": int(row[2])}
	for row in d.get("calibers", []):
		c.calibers[int(row[0])] = StringName(String(row[1]))
		c.reactions[int(row[0])] = int(row[2])
	for row in d.get("cooldowns", []):
		c.fire_cooldowns[int(row[0])] = int(row[1])
	return c
