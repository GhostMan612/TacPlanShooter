# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name MissionPrepFlow
extends Control


enum Stage { BRIEFING, INTEL, ROSTER, KIT, TEAM, PLANNING }


var stage: int = int(Stage.BRIEFING)
var breadcrumb: Array[StringName] = [
	&"Briefing", &"Intel", &"Roster", &"Kit", &"Team", &"Planning",
]


func advance() -> void:
	stage = int(Stage.PLANNING) if stage >= int(Stage.PLANNING) - 1 else stage + 1


func retreat() -> void:
	stage = 0 if stage <= 0 else stage - 1


func stage_name() -> StringName:
	if stage < 0 or stage >= breadcrumb.size():
		return &"Briefing"
	return breadcrumb[stage]
