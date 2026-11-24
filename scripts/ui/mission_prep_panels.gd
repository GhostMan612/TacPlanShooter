# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name MissionPrepPanels
extends Node


var briefing: Control = null
var intel: Control = null
var roster: Control = null
var kit: Control = null
var team: Control = null


func load_panels() -> void:
	briefing = Control.new()
	intel = Control.new()
	roster = Control.new()
	kit = Control.new()
	team = Control.new()
