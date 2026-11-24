# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name ThemeManager
extends Node


enum Style { DARK_TACTICAL, LIGHT_BLUEPRINT, NIGHT_OPS }


var current: int = int(Style.DARK_TACTICAL)
var accessible_scaling := true


func set_theme(t: int) -> void:
	current = t


func is_dark() -> bool:
	return current != int(Style.LIGHT_BLUEPRINT)


func set_accessible_scaling(on: bool) -> void:
	accessible_scaling = on


func apply() -> void:
	match current:
		Style.LIGHT_BLUEPRINT:
			pass
		Style.NIGHT_OPS:
			pass
		Style.DARK_TACTICAL:
			pass
