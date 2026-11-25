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


static func intel_summary(m: GreyboxMap) -> Dictionary:
	var out := {
		"enemies": 0,
		"archetypes": {},
		"doors": 0,
		"objectives": 0,
		"extractions": 0,
		"chokepoints": [],
		"floors": 1,
	}
	if m == null:
		return out
	out["floors"] = maxi(1, m.floor_count)
	for fl in range(maxi(1, m.floor_count)):
		var fm: GreyboxMap = m if fl == 0 else m.slice_map(fl)
		out["doors"] = int(out["doors"]) + fm.door_cells.size()
		out["objectives"] = int(out["objectives"]) + fm.objectives.size()
		out["extractions"] = int(out["extractions"]) + fm.extraction_zones.size()
		for sp in fm.ai_spawns:
			out["enemies"] = int(out["enemies"]) + 1
			var arch := String(sp.get("archetype", "sentry")).replace("_", " ").to_upper()
			if arch == "":
				arch = "SENTRY"
			var counts: Dictionary = out["archetypes"]
			counts[arch] = int(counts.get(arch, 0)) + 1
			out["archetypes"] = counts
		for cp in fm.chokepoints:
			var cell := MapEditorValidator.cell_of(cp)
			(out["chokepoints"] as Array).append("F%d:%s%02d" % [fl + 1, MapRenderer.col_letter(cell.x), cell.y + 1])
	return out


static func default_unit_kit(idx: int) -> Dictionary:
	var base := ArmoryScreen.default_roster()
	var prof: UnitProfile = base[idx % base.size()]
	var sq := String(SquadConfig.SQUADS[idx % SquadConfig.SQUADS.size()])
	var weapon_label := "CARBINE 5.56" if idx % 2 == 0 else "SMG 9MM"
	var caliber := "5.56" if idx % 2 == 0 else "9mm"
	var tool_label := "DEMOLITIONS" if idx % 2 == 0 else "UNDERDOOR CAM"
	var hb := 0 if idx % 2 == 0 else 2
	return {
		"operative_id": prof.operative_id,
		"codename": String(prof.codename).to_upper(),
		"role": ArmoryScreen.role_name(prof.role),
		"squad": sq,
		"caliber": caliber,
		"armor_class": "light",
		"heartbeat_radius": hb,
		"weapon_label": weapon_label,
		"tool_label": tool_label,
	}


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
