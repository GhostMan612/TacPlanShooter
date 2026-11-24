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


var PALETTES: Dictionary = {
	&"dark_tactical": {
		"bg": Color.html("#0B0F14"), "accent": Color.html("#2DD4BF"),
		"ink": Color.html("#E5E7EB"), "amber": Color.html("#F59E0B"),
		"red": Color.html("#EF4444"), "panel": Color.html("#111822"),
	},
	&"light_blueprint": {
		"bg": Color.html("#F4F6F8"), "accent": Color.html("#1D4ED8"),
		"ink": Color.html("#0F172A"), "amber": Color.html("#F59E0B"),
		"red": Color.html("#EF4444"), "panel": Color.html("#E2E8ED"),
	},
	&"night_ops": {
		"bg": Color.html("#050A06"), "accent": Color.html("#22C55E"),
		"ink": Color.html("#E5E7EB"), "amber": Color.html("#F59E0B"),
		"red": Color.html("#EF4444"), "panel": Color.html("#101610"),
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
	var normal := StyleBoxFlat.new()
	normal.set_content_margin_all(4)
	normal.set_corner_radius_all(2)
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_color = pal["accent"]
	normal.bg_color = pal["panel"]
	var hover := StyleBoxFlat.new()
	hover.set_content_margin_all(4)
	hover.set_corner_radius_all(2)
	hover.bg_color = pal["accent"]
	hover.bg_color.a = 0.25
	t.set_stylebox(&"PanelContainer", &"Control", normal)
	t.set_stylebox(&"Button", &"Control", normal)
	t.set_stylebox(&"Button", &"Button", hover)
	var font: Color = pal["ink"] if current == int(Style.LIGHT_BLUEPRINT) else Color.html("#E5E7EB")
	t.set_color(&"normal_font_color", &"Control", font)
	if is_inside_tree():
		get_tree().root.theme = t
	applied_theme = t
	theme_changed.emit(pal)


func _palette() -> Dictionary:
	var names := [&"dark_tactical", &"light_blueprint", &"night_ops"]
	var idx: int = clamp(current, 0, 2)
	return PALETTES.get(names[idx], PALETTES[&"dark_tactical"])
