# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name MissionPrepFlow
extends Node2D


enum Stage { BRIEFING, INTEL, ROSTER, KIT, TEAM, PLANNING }


var stage: int = int(Stage.BRIEFING)


func advance() -> void:
	stage = int(Stage.PLANNING) if stage >= int(Stage.PLANNING) - 1 else stage + 1


func retreat() -> void:
	stage = 0 if stage <= 0 else stage - 1
