# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name HostageAi
extends RefCounted


enum State { CAPTIVE, FOLLOW_ESCORT, EXTRACTED }


var state := int(State.CAPTIVE)
var duck_on_blasts := false


func transition(s: int) -> void:
	state = s


func duck(on: bool) -> void:
	duck_on_blasts = on
