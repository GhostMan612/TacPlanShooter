# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name SimDrone
extends RefCounted


enum Class { GROUND_RECON, MICRO_UAV, UTILITY }


var id := -1
var owner_op := -1
var pos := Vector2.ZERO
var kind := int(Class.GROUND_RECON)
var battery := 100
var signal_strength := 100
var destroyed := false


func to_dict() -> Dictionary:
	return {
		"id": id,
		"owner_op": owner_op,
		"kind": kind,
		"battery": battery,
		"signal_strength": signal_strength,
		"destroyed": destroyed,
	}


static func from_dict(d: Dictionary) -> SimDrone:
	var v := SimDrone.new()
	v.id = int(d.get("id", -1))
	v.owner_op = int(d.get("owner_op", -1))
	v.kind = int(d.get("kind", int(Class.GROUND_RECON)))
	v.battery = int(d.get("battery", 100))
	v.signal_strength = int(d.get("signal_strength", 100))
	v.destroyed = bool(d.get("destroyed", false))
	return v
