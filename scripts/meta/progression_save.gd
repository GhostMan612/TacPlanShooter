# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name ProgressionSave
extends RefCounted


const VERSION: int = 1
const SAVE_PATH := "user://progression.json"


var profiles := []
var campaign_state := {}


func save_json() -> String:
	var parts := []
	for p in profiles:
		parts.append("{\"operative_id\":%d,\"codename\":\"%s\",\"xp\":%d,\"role\":%d}" % [
			p.operative_id,
			String(p.codename).replace("\"", ""),
			p.xp,
			p.role,
		])
	return "{\"version\":%d,\"profiles\":[%s],\"campaign\":%s}" % [
		VERSION,
		",".join(parts),
		JSON.stringify(campaign_state),
	]


func save_to_disk() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(save_json())
		f.close()


static func load_from_disk() -> ProgressionSave:
	var s := ProgressionSave.new()
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f != null:
			s.load_json(f.get_as_text())
			f.close()
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
