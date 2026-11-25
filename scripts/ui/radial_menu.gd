# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name RadialMenu
extends Control


signal go_code_selected(code: StringName)


var _rad_buttons: Array[Button] = []
var radius: float = 128.0


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func open_at(pos: Vector2) -> void:
	position = pos - Vector2(radius, radius)
	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	size = Vector2(radius * 2.0, radius * 2.0)
	_rebuild()
	visible = true
	queue_redraw()


func close_menu() -> void:
	visible = false


func _rebuild() -> void:
	for c in _rad_buttons:
		if is_instance_valid(c):
			c.queue_free()
	_rad_buttons.clear()
	var texts: Array[StringName] = [&"alpha", &"bravo", &"charlie", &"delta"]
	var btn_sz := Vector2(88.0, 88.0)
	for i in range(texts.size()):
		var b := Button.new()
		b.text = String(texts[i]).to_upper()
		b.size = btn_sz
		var ang := float(i) / float(texts.size()) * TAU - PI * 0.5
		b.position = Vector2(radius + cos(ang) * radius - btn_sz.x * 0.5, radius + sin(ang) * radius - btn_sz.y * 0.5)
		b.pressed.connect(_on_go_code.bind(texts[i]))
		add_child(b)
		_rad_buttons.append(b)


func _on_go_code(code: StringName) -> void:
	close_menu()
	go_code_selected.emit(code)
