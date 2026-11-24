# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name AcousticBus
extends Node


var ducked := false


func duck() -> void:
	ducked = true


func unduck() -> void:
	ducked = false


func squelch_radio() -> void:
	pass


func telemetry_blip() -> void:
	pass
