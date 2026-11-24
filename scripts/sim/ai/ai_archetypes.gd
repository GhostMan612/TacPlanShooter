# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name AiArchetypes
extends RefCounted


enum Archetype { PATROL_SENTRY, ROOM_ANCHOR, TACTICAL_FLANKER, HEAVY_GUNNER, TECH_JAMMER, HOSTAGE_GUARD }
enum Role { PATROL, INVESTIGATE_LKP, ANCHOR, SUPPRESSOR, FLANKER, RUNNER, TECH, HOSTAGE_COERCE }


const ARCHETYPES: Dictionary = {
	&"patrol_sentry": {"reaction_ticks": 24, "focal_range": 10, "hearing_mult": 1.0, "base_morale": 55, "preferred_role": int(Role.PATROL)},
	&"room_anchor": {"reaction_ticks": 18, "focal_range": 12, "hearing_mult": 0.9, "base_morale": 70, "preferred_role": int(Role.ANCHOR)},
	&"tactical_flanker": {"reaction_ticks": 15, "focal_range": 11, "hearing_mult": 1.15, "base_morale": 80, "preferred_role": int(Role.FLANKER)},
	&"heavy_gunner": {"reaction_ticks": 22, "focal_range": 13, "hearing_mult": 0.85, "base_morale": 90, "preferred_role": int(Role.SUPPRESSOR)},
	&"tech_jammer": {"reaction_ticks": 26, "focal_range": 9, "hearing_mult": 1.1, "base_morale": 60, "preferred_role": int(Role.RUNNER)},
	&"hostage_guard": {"reaction_ticks": 20, "focal_range": 9, "hearing_mult": 1.0, "base_morale": 65, "preferred_role": int(Role.HOSTAGE_COERCE)},
}


static func by_name(name: StringName) -> Dictionary:
	return ARCHETYPES.get(name, ARCHETYPES[&"patrol_sentry"])
