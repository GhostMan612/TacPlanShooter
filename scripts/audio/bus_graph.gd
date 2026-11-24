# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name BusGraph
extends RefCounted


const BUSES: Array[StringName] = [&"BGM", &"Ambient", &"TacticalSFX", &"RadioComms", &"StressHeartbeat"]


static func ensure_buses() -> void:
	for n in BUSES:
		if AudioServer.get_bus_index(n) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, String(n))
			AudioServer.set_bus_send(AudioServer.get_bus_count() - 1, &"Master")


static func set_linear(bus: StringName, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	var v := clampf(value, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))


static func apply_volumes(settings: Dictionary) -> void:
	ensure_buses()
	set_linear(&"Master", float(settings.get("master", 0.8)))
	set_linear(&"BGM", float(settings.get("bgm", 0.6)))
	set_linear(&"Ambient", float(settings.get("sfx", 0.8)))
	set_linear(&"TacticalSFX", float(settings.get("sfx", 0.8)))
	set_linear(&"StressHeartbeat", float(settings.get("sfx", 0.8)))
	set_linear(&"RadioComms", float(settings.get("radio", 0.7)))
