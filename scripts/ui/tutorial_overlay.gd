# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name TutorialOverlay
extends CanvasLayer


signal completed

const STEPS: Array[String] = [
	"Hold/tap R1 and draw or tap a route toward the entry door.",
	"Tap a waypoint and assign Go-Code ALPHA to sync your entry.",
	"Tap 2.5D, EYE, or the yaw arrows to inspect the 3D building.",
	"Tap EXECUTE, then hit ALPHA when your team stacks up.",
	"Tap R1 or B1 during combat for live EYE-level Tap-In control!",
]
const SETTINGS_PATH := "user://settings.json"


var step: int = 0
var active: bool = false
var _panel: PanelContainer = null
var _label: Label = null
var _settings: Dictionary = {}


func _ready() -> void:
	layer = 12
	_settings = _load_settings()
	active = not bool(_settings.get("tutorial_completed", false))
	if active:
		_build()
		_set_step(0)


func _load_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return {}
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}


func _save_settings() -> void:
	_settings["tutorial_completed"] = true
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_settings))
		f.close()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "TutorialCallout"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.08, 0.12, 0.82)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(0.18, 0.83, 0.75, 0.8)
	sb.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_panel.position = Vector2(12.0, 76.0)
	_label = Label.new()
	_label.name = "TutorialText"
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_color_override("font_color", Color(0.88, 0.95, 1.0))
	_panel.add_child(_label)
	var skip := Button.new()
	skip.name = "TutorialSkip"
	skip.text = "SKIP"
	skip.custom_minimum_size = Vector2(64.0, 44.0)
	skip.pressed.connect(skip_tutorial)
	skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip.position = Vector2(-72.0, 76.0)
	add_child(skip)
	add_child(_panel)


func _set_step(next_step: int) -> void:
	step = clampi(next_step, 0, STEPS.size() - 1)
	if _label != null:
		_label.text = "TUTORIAL %d/5  |  %s" % [step + 1, STEPS[step]]


func notify_route() -> void:
	if active and step == 0:
		_set_step(1)


func notify_gocode() -> void:
	if active and step == 1:
		_set_step(2)


func notify_camera() -> void:
	if active and step == 2:
		_set_step(3)


func notify_execution() -> void:
	if active and step == 3:
		_set_step(4)


func notify_tapin() -> void:
	if active and step == 4:
		_finish()


func notify_mission_end() -> void:
	if active:
		_finish()


func _finish() -> void:
	active = false
	_save_settings()
	if _panel != null:
		_panel.visible = false
	completed.emit()


func skip_tutorial() -> void:
	_finish()
