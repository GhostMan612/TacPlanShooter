# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name RadialMenu
extends Control


signal go_code_selected(code: StringName)


var _rad_buttons: Array = []
var radius: float = 112.0


func open_at(pos: Vector2) -> void:
	position = pos - Vector2(radius, radius)
	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	_rebuild()
	queue_redraw()


func _rebuild() -> void:
	for c in _rad_buttons:
		c.queue_free()
	_rad_buttons = []
	var texts := [&"alpha", &"bravo", &"charlie", &"delta"]
	for i in range(texts.size()):
		var b := Button.new()
		b.text = String(texts[i])
		b.size = Vector2(48.0, 48.0)
		var ang := float(i) / texts.size() * 2 * PI - PI / 2.0
		b.rect_position = Vector2(radius + cos(ang) * radius - 24.0, radius + sin(ang) * radius - 24.0)
		b.button_down.connect(_on_go_code.bind(texts[i]))
		add_child(b)
		_rad_buttons.push_back(b)


func _on_go_code(code: StringName) -> void:
	go_code_selected.emit(code)
