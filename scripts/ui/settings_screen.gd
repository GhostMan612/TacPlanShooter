# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name SettingsScreen
extends Control


const VOLUME_KEYS: Array[String] = ["master", "bgm", "sfx", "radio"]
const VOLUME_LABELS: Array[String] = ["MASTER", "MUSIC", "EFFECTS", "RADIO"]


var theme_manager: ThemeManager = null
var settings: Dictionary = {}
var theme_buttons: Array[Button] = []
var sliders: Dictionary = {}


func _ready() -> void:
	theme_manager = ThemeManager.apply_saved()
	settings = ThemeManager.load_settings()
	var pal := theme_manager.palette()
	var col := UiKit.build_screen(self, pal)
	col.add_child(UiKit.button("< BACK", _go_back, settings))
	col.add_child(UiKit.heading("SETTINGS", pal))
	col.add_child(UiKit.caption("THEME", pal, false))
	var group := ButtonGroup.new()
	for i in range(ThemeManager.style_count()):
		var b := UiKit.button(ThemeManager.STYLE_NAMES[i].to_upper(), select_theme.bind(i), settings)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == theme_manager.current
		b.name = "Theme%d" % i
		theme_buttons.append(b)
		col.add_child(b)
	var large := CheckButton.new()
	large.name = "LargeTouch"
	large.text = "LARGE TOUCH TARGETS"
	large.custom_minimum_size = Vector2(0, ThemeManager.touch_min(theme_manager.accessible_scaling))
	large.button_pressed = theme_manager.accessible_scaling
	large.toggled.connect(set_accessible_scaling)
	col.add_child(large)
	for i in range(VOLUME_KEYS.size()):
		var key: String = VOLUME_KEYS[i]
		col.add_child(UiKit.caption(VOLUME_LABELS[i], pal, false))
		var s := HSlider.new()
		s.name = "Volume_" + key
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = float(settings.get(key, 0.5))
		s.custom_minimum_size = Vector2(0, 96)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.value_changed.connect(_on_volume.bind(key))
		sliders[key] = s
		col.add_child(s)
	var haptics := CheckButton.new()
	haptics.name = "Haptics"
	haptics.text = "HAPTIC FEEDBACK"
	haptics.custom_minimum_size = Vector2(0, ThemeManager.touch_min(theme_manager.accessible_scaling))
	haptics.button_pressed = bool(settings.get("haptics", true))
	haptics.toggled.connect(_on_haptics)
	col.add_child(haptics)
	col.add_child(UiKit.caption("Frame caps: %d FPS while planning, %d FPS during execution." % [SimConstants.PLANNING_FPS_CAP, SimConstants.EXECUTION_FPS_CAP], pal))
	print("[TacPlan] screen=settings theme=%d" % theme_manager.current)


func select_theme(t: int) -> void:
	if theme_manager == null or t == theme_manager.current:
		return
	theme_manager.set_theme(t)
	theme_manager.save()
	if is_inside_tree():
		get_tree().reload_current_scene()


func set_accessible_scaling(on: bool) -> void:
	if theme_manager == null:
		return
	theme_manager.set_accessible_scaling(on)
	theme_manager.save()
	if is_inside_tree():
		get_tree().reload_current_scene()


func _on_volume(value: float, key: String) -> void:
	settings[key] = clampf(value, 0.0, 1.0)
	_persist()
	BusGraph.apply_volumes(settings)


func _on_haptics(on: bool) -> void:
	settings["haptics"] = on
	_persist()


func _persist() -> void:
	var s := ThemeManager.load_settings()
	for k in VOLUME_KEYS:
		s[k] = settings.get(k, s[k])
	s["haptics"] = bool(settings.get("haptics", true))
	ThemeManager.save_settings(s)


func _go_back() -> void:
	ScreenRouter.goto_stage(ScreenRouter.Stage.TITLE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if UiKit.is_back_event(event):
		_go_back()
