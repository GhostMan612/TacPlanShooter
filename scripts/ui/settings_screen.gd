# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name SettingsScreen
extends Control


var theme_manager: ThemeManager = null
var accessible_scaling := false
var master_volume := 0.5
var bgm_volume := 0.4
var sfx_volume := 0.7
var radio_volume := 0.5
var haptics := true
var mobile_optimizations := true


func select_theme(t: int) -> void:
	if theme_manager != null:
		theme_manager.set_theme(t)


func set_accessible_scaling(on: bool) -> void:
	accessible_scaling = on
	if theme_manager != null:
		theme_manager.set_accessible_scaling(on)
