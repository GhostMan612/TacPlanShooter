class_name SplashScreen
extends Control


func _ready() -> void:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = 1.8
	t.timeout.connect(_on_splash_done)
	add_child(t)
	t.start()


func _on_splash_done() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")
