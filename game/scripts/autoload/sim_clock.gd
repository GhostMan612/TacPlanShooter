# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
extends Node

enum Phase { PLANNING, EXECUTION }

var phase: Phase = Phase.PLANNING
var tick: int = 0


func _ready() -> void:
	_apply_fps_cap()


func _physics_process(_delta: float) -> void:
	if phase == Phase.EXECUTION:
		advance_tick()


func start_execution() -> void:
	if phase == Phase.EXECUTION:
		return
	phase = Phase.EXECUTION
	_apply_fps_cap()
	EventBus.phase_changed.emit(phase)


func reset_to_planning() -> void:
	phase = Phase.PLANNING
	tick = 0
	_apply_fps_cap()
	EventBus.phase_changed.emit(phase)


func advance_tick() -> void:
	tick += 1
	EventBus.tick_advanced.emit(tick)


func _apply_fps_cap() -> void:
	Engine.max_fps = SimConstants.PLANNING_FPS_CAP if phase == Phase.PLANNING else SimConstants.EXECUTION_FPS_CAP
