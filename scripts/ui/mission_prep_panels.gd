# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name MissionPrepPanels
extends Node


enum Panel { BRIEFING, INTEL, ROSTER, KIT, TEAM, PLANNING }


var briefing: Control = null
var intel: Control = null
var roster: Control = null
var kit: Control = null
var team: Control = null
var planning: Control = null
var flow: MissionPrepFlow = null


func load_panels() -> void:
	flow = MissionPrepFlow.new()
	for i in range(int(Panel.PLANNING) + 1):
		var p := Control.new()
		match i:
			Panel.BRIEFING: briefing = p
			Panel.INTEL: intel = p
			Panel.ROSTER: roster = p
			Panel.KIT: kit = p
			Panel.TEAM: team = p
			Panel.PLANNING: planning = p
		add_child(p)
	add_child(flow)


func panel_at(i: int) -> Control:
	match i:
		Panel.BRIEFING: return briefing
		Panel.INTEL: return intel
		Panel.ROSTER: return roster
		Panel.KIT: return kit
		Panel.TEAM: return team
		Panel.PLANNING: return planning
	return briefing
