# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name UiKit
extends RefCounted


const SIDE_MARGIN := 56
const TOP_MARGIN := 120
const BOTTOM_MARGIN := 72


static func build_screen(screen: Control, pal: Dictionary) -> VBoxContainer:
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_PASS
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = pal["bg"]
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", SIDE_MARGIN)
	margin.add_theme_constant_override("margin_right", SIDE_MARGIN)
	margin.add_theme_constant_override("margin_top", TOP_MARGIN)
	margin.add_theme_constant_override("margin_bottom", BOTTOM_MARGIN)
	screen.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	var col := VBoxContainer.new()
	col.name = "Column"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	return col


static func heading(text: String, pal: Dictionary, font_px: int = 72) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_px)
	l.add_theme_color_override("font_color", pal["accent"])
	return l


static func caption(text: String, pal: Dictionary, muted: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", pal["muted"] if muted else pal["ink"])
	return l


static func button(text: String, on_press: Callable, settings: Dictionary) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, ThemeManager.touch_min(bool(settings.get("large_touch", false))))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	if bool(settings.get("haptics", false)):
		b.pressed.connect(Callable(Input, "vibrate_handheld").bind(12))
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


static func spacer(height_px: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height_px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func is_back_event(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_cancel")
