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
const ACTION_FUSE_TICKS: int = 45
const ACTION_COOLDOWN_TICKS: int = 60
const ACTION_MAX_RANGE_CELLS: int = 6
const ACTION_ENTITY_LIFE_TICKS: int = 30
const FRAG_DAMAGE: int = 25
const FRAG_RADIUS_CELLS: int = 2
