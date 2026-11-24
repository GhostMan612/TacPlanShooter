# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name ScreenRouter
extends Node


enum Stage { SPLASH, TITLE, LOADING, PREP, IN_MISSION, AAR }


signal advanced(stage: int)
var stage := int(Stage.SPLASH)


func to_scene(stage: int) -> void:
	var path := _scene_for(stage)
	if path != "":
		get_tree().change_scene_to_file(path)


func _scene_for(stage: int) -> String:
	match stage:
		int(Stage.SPLASH):
			return "res://scenes/splash.tscn"
		int(Stage.TITLE):
			return "res://scenes/title.tscn"
		int(Stage.LOADING):
			return "res://scenes/loading.tscn"
		int(Stage.PREP):
			return "res://scenes/planning.tscn"
		int(Stage.IN_MISSION):
			return "res://scenes/planning.tscn"
		int(Stage.AAR):
			return "res://scenes/aar.tscn"
	return ""


func advance() -> void:
	if stage < int(Stage.AAR):
		stage += 1
	advanced.emit(stage)
