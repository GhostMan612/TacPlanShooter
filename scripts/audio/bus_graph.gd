# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name BusGraph
extends Node


static func ensure_buses() -> void:
	for n in [&"BGM", &"Ambient", &"TacticalSFX", &"RadioComms", &"StressHeartbeat"]:
		if AudioServer.get_bus_index(n) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.get_bus_index(n), String(n))
