# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
extends Node

const GRID_CELL_SIZE: int = 16
const PLANNING_FPS_CAP: int = 30
const EXECUTION_FPS_CAP: int = 60

const STANCE_SPEED_MULTIPLIERS: Dictionary = {
	"blitz": 1.6,
	"normal": 1.0,
	"cautious": 0.5,
}

const STANCE_ACOUSTIC_RADIUS_MULTIPLIERS: Dictionary = {
	"blitz": 1.5,
	"normal": 1.0,
	"cautious": 0.35,
}

const GO_CODES: Array[StringName] = [&"alpha", &"bravo", &"charlie"]

const LOS_VERTEX_EPSILON_RAD: float = 0.00001
