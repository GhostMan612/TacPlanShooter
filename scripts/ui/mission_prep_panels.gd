# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name MissionPrepPanels
extends Node


enum PrepPanel { BRIEFING, INTEL, ROSTER, KIT, TEAM, PLANNING }


var briefing: Control = null
var intel: Control = null
var roster: Control = null
var kit: Control = null
var team: Control = null
var planning: Control = null
var flow: MissionPrepFlow = null
var contents: Dictionary = {}


func load_panels() -> void:
	flow = MissionPrepFlow.new()
	for i in range(int(PrepPanel.PLANNING) + 1):
		var p := Control.new()
		match i:
			PrepPanel.BRIEFING: briefing = p
			PrepPanel.INTEL: intel = p
			PrepPanel.ROSTER: roster = p
			PrepPanel.KIT: kit = p
			PrepPanel.TEAM: team = p
			PrepPanel.PLANNING: planning = p
		add_child(p)
	add_child(flow)
	set_content(PrepPanel.BRIEFING, "Mission objectives, threat background, commander notes")
	set_content(PrepPanel.INTEL, "Categorized dossiers (People, Organizations, Misc) + floor-plan markers")
	set_content(PrepPanel.ROSTER, "Synthetic operative pool (OPR_xx); 5 traits + 5 skills; select up to 4 from the unit pool")
	set_content(PrepPanel.KIT, "Primary + secondary weapons; 2 equipment slots; Light/Medium/Heavy armor")
	set_content(PrepPanel.TEAM, "Split up to 4 operatives into Red/Blue/Green/Gold squads; promote a leader")
	set_content(PrepPanel.PLANNING, "Color-coded routes on the 16 px grid; synchronized Go-Codes (Alpha/Bravo/Charlie/Delta); 3 ROE modes per waypoint")


func set_content(i: int, content: String) -> void:
	contents[i] = content


func content(i: int) -> String:
	return String(contents.get(i, ""))


func panel_at(i: int) -> Control:
	match i:
		PrepPanel.BRIEFING: return briefing
		PrepPanel.INTEL: return intel
		PrepPanel.ROSTER: return roster
		PrepPanel.KIT: return kit
		PrepPanel.TEAM: return team
		PrepPanel.PLANNING: return planning
	return briefing
