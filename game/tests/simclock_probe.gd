# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
extends Node


func _ready() -> void:
	print("[PROBE] planning_cap=%d" % Engine.max_fps)
	SimClock.start_execution()
	print("[PROBE] execution_cap=%d phase=%d" % [Engine.max_fps, SimClock.phase])
	SimClock.reset_to_planning()
	print("[PROBE] back_to_planning_cap=%d phase=%d" % [Engine.max_fps, SimClock.phase])
	get_tree().quit(0)
