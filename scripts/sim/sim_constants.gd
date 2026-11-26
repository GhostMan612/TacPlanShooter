# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name SimConstants
extends Object

const GRID_CELL_SIZE_PX: int = 16
const BASE_SPEED_CELLS_PER_SEC: float = 4.0
const PLANNING_FPS_CAP: int = 30
const EXECUTION_FPS_CAP: int = 60

enum Difficulty { RECRUIT, VETERAN, TIER_ONE }
const REACTION_MULTIPLIERS: Array[float] = [1.35, 1.0, 0.8]
const GOAP_CADENCE: Array[int] = [24, 12, 8]

const STANCE_SPEED_MULTIPLIERS: Dictionary = {
	&"blitz": 1.6,
	&"normal": 1.0,
	&"cautious": 0.5,
}

const STANCE_ACOUSTIC_RADIUS_MULTIPLIERS: Dictionary = {
	&"blitz": 1.5,
	&"normal": 1.0,
	&"cautious": 0.35,
}

const GO_CODES: Array[StringName] = [&"alpha", &"bravo", &"charlie", &"delta"]

const LOS_VERTEX_EPSILON_RAD: float = 0.00001
const TAPIN_HANDOFF_TICKS: int = 30
const TAPIN_MAX_BURST_TICKS: int = 600
const TAPIN_COOLDOWN_TICKS: int = 480
const TAPIN_UNIT_COOLDOWN_TICKS: int = 720
const TAPIN_COMMAND_POINTS_MAX: int = 4
const LOCKSTEP_INPUT_DELAY_TICKS: int = 3
const ACTION_FUSE_TICKS: int = 45
const ACTION_COOLDOWN_TICKS: int = 60
const ACTION_MAX_RANGE_CELLS: int = 6
const ACTION_ENTITY_LIFE_TICKS: int = 30
const FRAG_DAMAGE: int = 25
const FRAG_RADIUS_CELLS: int = 2
