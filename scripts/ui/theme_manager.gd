# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name ThemeManager
extends RefCounted


enum Style { DARK_TACTICAL, LIGHT_BLUEPRINT, NIGHT_OPS }


signal theme_changed(pal: Dictionary)


const SETTINGS_PATH := "user://settings.json"
const STYLE_NAMES: Array[String] = ["Dark Tactical", "Light Blueprint", "Night-Ops NVG"]
const FONT_SIZE_STANDARD := 40
const FONT_SIZE_LARGE := 48
const TITLE_FONT_SIZE := 72
const TOUCH_MIN_STANDARD := 128
const TOUCH_MIN_LARGE := 160


var current: int = int(Style.DARK_TACTICAL)
var accessible_scaling := false
var applied_theme: Theme = null


static func palette_for(style: int) -> Dictionary:
	if style == int(Style.LIGHT_BLUEPRINT):
		return {
			"bg": Color("#F4F6F8"), "panel": Color("#E2E8ED"), "panel_hi": Color("#CBD5E1"),
			"accent": Color("#1D4ED8"), "accent_dim": Color("#BFDBFE"), "ink": Color("#0F172A"),
			"muted": Color("#64748B"), "amber": Color("#B45309"), "red": Color("#DC2626"),
			"grid": Color(0.11, 0.31, 0.85, 0.18), "wall": Color("#334155"),
			"door_closed": Color("#B45309"), "door_open": Color("#15803D"),
		}
	if style == int(Style.NIGHT_OPS):
		return {
			"bg": Color("#050A06"), "panel": Color("#0B140C"), "panel_hi": Color("#12301A"),
			"accent": Color("#22C55E"), "accent_dim": Color("#14532D"), "ink": Color("#86EFAC"),
			"muted": Color("#3F6212"), "amber": Color("#A3E635"), "red": Color("#F87171"),
			"grid": Color(0.13, 0.77, 0.37, 0.16), "wall": Color("#1A2E1C"),
			"door_closed": Color("#A3E635"), "door_open": Color("#22C55E"),
		}
	return {
		"bg": Color("#0B0F14"), "panel": Color("#111822"), "panel_hi": Color("#1A2533"),
		"accent": Color("#2DD4BF"), "accent_dim": Color("#134E4A"), "ink": Color("#E5E7EB"),
		"muted": Color("#64748B"), "amber": Color("#F59E0B"), "red": Color("#EF4444"),
		"grid": Color(0.18, 0.83, 0.75, 0.16), "wall": Color("#1E293B"),
		"door_closed": Color("#F59E0B"), "door_open": Color("#22C55E"),
	}


static func style_count() -> int:
	return STYLE_NAMES.size()


static func touch_min(large: bool) -> int:
	return TOUCH_MIN_LARGE if large else TOUCH_MIN_STANDARD


static func font_size(large: bool) -> int:
	return FONT_SIZE_LARGE if large else FONT_SIZE_STANDARD


static func default_settings() -> Dictionary:
	return {
		"theme": int(Style.DARK_TACTICAL),
		"large_touch": false,
		"master": 0.8,
		"bgm": 0.6,
		"sfx": 0.8,
		"radio": 0.7,
		"haptics": true,
	}


const SCHEMA_VERSION: int = 1


static func load_from_string(raw: String) -> Dictionary:
	var out := default_settings()
	out["schema_version"] = SCHEMA_VERSION
	if raw.is_empty():
		return out
	var parser := JSON.new()
	if parser.parse(raw) != OK:
		return out
	var parsed: Variant = parser.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return out
	var d: Dictionary = parsed
	for k in out.keys():
		if d.has(k):
			out[k] = d[k]
	return out


static func load_settings() -> Dictionary:
	var out := default_settings()
	out["schema_version"] = SCHEMA_VERSION
	if not FileAccess.file_exists(SETTINGS_PATH):
		return out
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return out
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		var bak := FileAccess.open(SETTINGS_PATH + ".bak", FileAccess.WRITE)
		if bak != null:
			bak.store_string(text)
			bak.close()
		return out
	var d: Dictionary = parsed
	for k in out.keys():
		if d.has(k):
			out[k] = d[k]
	out["theme"] = clampi(int(out["theme"]), 0, style_count() - 1)
	out["large_touch"] = bool(out["large_touch"])
	out["haptics"] = bool(out["haptics"])
	for k in ["master", "bgm", "sfx", "radio"]:
		out[k] = clampf(float(out[k]), 0.0, 1.0)
	return out


static func save_settings(settings: Dictionary) -> bool:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(settings))
	f.close()
	return true


static func build_theme(pal: Dictionary, large: bool) -> Theme:
	var t := Theme.new()
	var fs := font_size(large)
	var pad := float(touch_min(large) - fs) * 0.5 - 6.0
	t.default_font_size = fs
	var normal := _box(pal["panel"], pal["accent"], 2, pad)
	var hover := _box(pal["panel_hi"], pal["accent"], 2, pad)
	var pressed := _box(pal["accent_dim"], pal["accent"], 3, pad)
	var disabled := _box(pal["panel"], pal["muted"], 1, pad)
	var focus := _box(Color(0, 0, 0, 0), pal["ink"], 3, pad)
	for type_name in ["Button", "OptionButton", "CheckButton", "CheckBox"]:
		t.set_stylebox("normal", type_name, normal)
		t.set_stylebox("hover", type_name, hover)
		t.set_stylebox("pressed", type_name, pressed)
		t.set_stylebox("hover_pressed", type_name, pressed)
		t.set_stylebox("disabled", type_name, disabled)
		t.set_stylebox("focus", type_name, focus)
		t.set_color("font_color", type_name, pal["ink"])
		t.set_color("font_hover_color", type_name, pal["ink"])
		t.set_color("font_pressed_color", type_name, pal["accent"])
		t.set_color("font_hover_pressed_color", type_name, pal["accent"])
		t.set_color("font_focus_color", type_name, pal["ink"])
		t.set_color("font_disabled_color", type_name, pal["muted"])
	var panel := _box(pal["panel"], pal["accent_dim"], 2, 24.0)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_color("font_color", "Label", pal["ink"])
	t.set_constant("separation", "VBoxContainer", 24)
	t.set_constant("separation", "HBoxContainer", 16)
	t.set_constant("h_separation", "GridContainer", 16)
	t.set_constant("v_separation", "GridContainer", 16)
	var track := _box(pal["panel_hi"], pal["accent_dim"], 1, 0.0)
	track.content_margin_top = 12.0
	track.content_margin_bottom = 12.0
	var fill := _box(pal["accent"], pal["accent"], 0, 0.0)
	fill.content_margin_top = 12.0
	fill.content_margin_bottom = 12.0
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	return t


static func _box(bg: Color, border: Color, border_px: int, pad: float) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(border_px)
	b.set_corner_radius_all(6)
	b.content_margin_left = maxf(pad, 16.0)
	b.content_margin_right = maxf(pad, 16.0)
	b.content_margin_top = maxf(pad, 0.0)
	b.content_margin_bottom = maxf(pad, 0.0)
	return b


func load_saved() -> void:
	var s := load_settings()
	current = int(s["theme"])
	accessible_scaling = bool(s["large_touch"])


func save() -> bool:
	var s := load_settings()
	s["theme"] = current
	s["large_touch"] = accessible_scaling
	return save_settings(s)


func set_theme(t: int) -> void:
	current = clampi(t, 0, style_count() - 1)


func is_dark() -> bool:
	return current != int(Style.LIGHT_BLUEPRINT)


func set_accessible_scaling(on: bool) -> void:
	accessible_scaling = on


func palette() -> Dictionary:
	return palette_for(current)


func apply() -> void:
	var pal := palette()
	applied_theme = build_theme(pal, accessible_scaling)
	RenderingServer.set_default_clear_color(pal["bg"])
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.theme = applied_theme
	theme_changed.emit(pal)


static func apply_saved() -> ThemeManager:
	var tm := ThemeManager.new()
	tm.load_saved()
	tm.apply()
	return tm
