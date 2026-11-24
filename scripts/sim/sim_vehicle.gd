# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name SimVehicle
extends RefCounted


enum Type { RAID_VAN, APC, EXTRACTION_SUV }


var id := -1
var type := int(Type.RAID_VAN)
var pos := Vector2.ZERO


func to_dict() -> Dictionary:
	return {"id": id, "type": type, "px": pos.x, "py": pos.y}


static func from_dict(d: Dictionary) -> SimVehicle:
	var v := SimVehicle.new()
	v.id = int(d.get("id", -1))
	v.type = int(d.get("type", int(Type.RAID_VAN)))
	v.pos = Vector2(float(d.get("px", 0.0)), float(d.get("py", 0.0)))
	return v
