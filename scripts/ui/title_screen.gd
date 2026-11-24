class_name TitleScreen
extends Control

var campaign := 10
var quick := 1
var two_player := 2
var hq_armory := 3
var settings := 4
var credits := 5
var map_editor := 6


func ready_state() -> void:
	pass


func _ready() -> void:
	var b := Button.new()
	b.text = "MAP EDITOR"
	b.rect_min_size = Vector2(150.0, 44.0)
	add_child(b)
	b.button_down.connect(_on_map_editor)


func _on_map_editor() -> void:
	print("[TacPlan] MAP EDITOR selected")

