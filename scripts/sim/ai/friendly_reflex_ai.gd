# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name FriendlyReflexAi
extends RefCounted


enum RoeMode { ENGAGE, ADVANCE, ESCORT }


var mode := int(RoeMode.ENGAGE)
var suppression := 0


func set_roe(m: int) -> void:
	mode = m


func snap_check(hostage_cells: Array) -> bool:
	return suppression >= 85
