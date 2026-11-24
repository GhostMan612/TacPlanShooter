# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name ScreenRouter
extends Node


enum Stage { SPLASH, TITLE, LOADING, PREP, IN_MISSION, AAR }


var stage := int(Stage.SPLASH)


func advance() -> void:
	if stage < int(Stage.AAR):
		stage += 1
