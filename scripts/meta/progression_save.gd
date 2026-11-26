# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name ProgressionSave
extends RefCounted


const VERSION: int = 1
const SCHEMA_VERSION: int = 1
const SAVE_PATH := "user://progression.json"
const DEFAULT_UNLOCKS: Array[String] = [
	"weapon_smg_standard",
	"weapon_carbine_compact",
	"weapon_pistol_standard",
	"armor_light_iia",
	"armor_medium_ii",
	"tool_underdoor_cam",
	"tool_demolitions",
]


var profiles := []
var campaign_state := {}


func save_json() -> String:
	var parts: Array[String] = []
	for p in profiles:
		parts.append(JSON.stringify((p as UnitProfile).to_dict()))
	return "{\"version\":%d,\"profiles\":[%s],\"campaign\":%s}" % [
		VERSION,
		",".join(parts),
		JSON.stringify(campaign_state),
	]


func unlocked_items() -> Array[String]:
	var out: Array[String] = []
	for d in DEFAULT_UNLOCKS:
		out.append(d)
	var saved: Variant = campaign_state.get("unlocks", [])
	if typeof(saved) == TYPE_ARRAY:
		for entry in saved:
			var s := String(entry)
			if s != "" and not out.has(s):
				out.append(s)
	return out


func unlock_item(item: StringName, cost_rp: int) -> bool:
	var key := String(item)
	if unlocked_items().has(key):
		return true
	var rp := int(campaign_state.get("total_rp", 0))
	var cost := maxi(cost_rp, 0)
	if rp < cost:
		return false
	campaign_state["total_rp"] = rp - cost
	var arr: Array = []
	var prev: Variant = campaign_state.get("unlocks", [])
	if typeof(prev) == TYPE_ARRAY:
		for e in prev:
			arr.append(String(e))
	if not arr.has(key):
		arr.append(key)
	campaign_state["unlocks"] = arr
	return true


func save_to_disk() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(save_json())
		f.close()


static func load_from_string(raw: String) -> ProgressionSave:
	var s := ProgressionSave.new()
	s.load_json(raw)
	return s


static func load_from_disk() -> ProgressionSave:
	var s := ProgressionSave.new()
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f != null:
			var raw := f.get_as_text()
			f.close()
			if not s.load_json(raw):
				var bak := FileAccess.open(SAVE_PATH + ".bak", FileAccess.WRITE)
				if bak != null:
					bak.store_string(raw)
					bak.close()
				return ProgressionSave.new()
	return s


func load_json(json: String) -> bool:
	if json.is_empty():
		return false
	var j := JSON.new()
	if j.parse(json) != OK:
		return false
	var d: Dictionary = j.data
	if int(d.get("version", 0)) != VERSION:
		return false
	profiles.clear()
	for pd in d.get("profiles", []):
		profiles.append(UnitProfile.from_dict(pd))
	campaign_state = d.get("campaign", {}).duplicate(true)
	return true
