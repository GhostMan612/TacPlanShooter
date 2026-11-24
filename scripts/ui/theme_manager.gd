# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name ThemeManager
extends Node


enum Style { DARK_TACTICAL, LIGHT_BLUEPRINT, NIGHT_OPS }


signal theme_changed(palette: Dictionary)


var current: int = int(Style.DARK_TACTICAL)
var accessible_scaling := true
var applied_theme: Theme = null


const PALETTES: Dictionary = {
	&"dark_tactical": {
		"bg": Color(0x0B, 0x0F, 0x14), "accent": Color(0x2D, 0xD4, 0xBF),
		"ink": Color(0x0F, 0x17, 0x2A), "amber": Color(0xF5, 0x9E, 0x0B),
		"red": Color(0xEF, 0x44, 0x44), "panel": Color(0x11, 0x18, 0x22),
	},
	&"light_blueprint": {
		"bg": Color(0xF4, 0xF6, 0xF8), "accent": Color(0x1D, 0x4E, 0xD8),
		"ink": Color(0x0F, 0x17, 0x2A), "amber": Color(0xF5, 0x9E, 0x0B),
		"red": Color(0xEF, 0x44, 0x44), "panel": Color(0xE2, 0xE8, 0xED),
	},
	&"night_ops": {
		"bg": Color(0x05, 0x0A, 0x06), "accent": Color(0x22, 0xC5, 0x5E),
		"ink": Color(0x0F, 0x17, 0x2A), "amber": Color(0xF5, 0x9E, 0x0B),
		"red": Color(0xEF, 0x44, 0x44), "panel": Color(0x10, 0x16, 0x0E),
	},
}


func set_theme(t: int) -> void:
	current = t


func is_dark() -> bool:
	return current != int(Style.LIGHT_BLUEPRINT)


func set_accessible_scaling(on: bool) -> void:
	accessible_scaling = on


func apply() -> void:
	var pal := _palette()
	var t := Theme.new()
	var st := StyleBoxFlat.new()
	st.set_content_margin_all(8)
	st.set_corner_radius_all(6)
	st.bg_color = pal["bg"]
	var panel := StyleBoxFlat.new()
	panel.set_content_margin_all(4)
	panel.set_corner_radius_all(2)
	panel.border_width_top = 1
	panel.border_width_bottom = 1
	panel.border_width_left = 1
	panel.border_width_right = 1
	panel.border_color = pal["accent"]
	panel.bg_color = pal["panel"]
	t.set_stylebox(&"panel", &"Control", panel)
	t.set_stylebox(&"normal", &"Control", st)
	t.set_color(&"normal_font_color", &"Control", Color(0.92, 0.96, 1.0))
	applied_theme = t
	theme_changed.emit(pal)


func _palette() -> Dictionary:
	var name: int = [Style.DARK_TACTICAL, Style.LIGHT_BLUEPRINT, Style.NIGHT_OPS][current]
	return PALETTES.get(name, PALETTES[&"dark_tactical"])
