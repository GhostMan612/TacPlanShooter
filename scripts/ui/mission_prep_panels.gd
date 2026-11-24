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
var contents: Dictionary = {}


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
	set_content(Panel.BRIEFING, "Mission objectives, threat background, commander notes")
	set_content(Panel.INTEL, "Categorized dossiers (People, Organizations, Misc) + floor-plan markers")
	set_content(Panel.ROSTER, "Synthetic operative pool (OPR_xx); 5 traits + 5 skills; select up to 4 from the unit pool")
	set_content(Panel.KIT, "Primary + secondary weapons; 2 equipment slots; Light/Medium/Heavy armor")
	set_content(Panel.TEAM, "Split up to 4 operatives into Red/Blue/Green/Gold squads; promote a leader")
	set_content(Panel.PLANNING, "Color-coded routes on the 16 px grid; synchronized Go-Codes (Alpha/Bravo/Charlie/Delta); 3 ROE modes per waypoint")


func set_content(i: int, content: String) -> void:
	contents[i] = content


func content(i: int) -> String:
	return String(contents.get(i, ""))


func panel_at(i: int) -> Control:
	match i:
		Panel.BRIEFING: return briefing
		Panel.INTEL: return intel
		Panel.ROSTER: return roster
		Panel.KIT: return kit
		Panel.TEAM: return team
		Panel.PLANNING: return planning
	return briefing
