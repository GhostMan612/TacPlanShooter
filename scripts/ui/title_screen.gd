class_name TitleScreen
extends Control

var campaign := 10
var quick := 1
var two_player := 2
var hq_armory := 3
var settings := 4
var credits := 5
var map_editor := 6
var scenes: Dictionary = {}


func ready_state() -> void:
	pass


func _ready() -> void:
	scenes[campaign] = "res://scenes/planning.tscn"
	scenes[quick] = "res://scenes/planning.tscn"
	scenes[two_player] = "res://scenes/planning.tscn"
	scenes[map_editor] = "res://scenes/map_editor.tscn"
	scenes[hq_armory] = "res://scenes/title.tscn"
	scenes[settings] = "res://scenes/title.tscn"
	scenes[credits] = "res://scenes/title.tscn"
	_add_button("Campaign", "campaign")
	_add_button("Quick Operation", "quick")
	_add_button("2-Player Co-op", "two_player")
	var me := _add_button("Map Editor", "map_editor")
	me.rect_position = Vector2(330.0, 0.0)
	var hq := _add_button("HQ & Armory", "hq_armory")
	hq.rect_position = Vector2(510.0, 0.0)
	var st := _add_button("Settings", "settings")
	st.rect_position = Vector2(700.0, 0.0)
	var cr := _add_button("Credits", "credits")
	cr.rect_position = Vector2(880.0, 0.0)


func _add_button(label: StringName, key: StringName) -> Button:
	var b: Button = Button.new()
	b.text = label
	b.rect_min_size = Vector2(150.0, 44.0)
	b.button_down.connect(_on_select.bind(key))
	add_child(b)
	return b


func _on_select(key: StringName) -> void:
	var v: String = scenes.get(key)
	if v != null:
		get_tree().change_scene_to_file(v)
