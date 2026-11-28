# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name ReplayManifest
extends RefCounted


const SCHEMA_VERSION: int = 1
const MANIFEST_FORMAT: String = "tacplan-replay"
const APP_VERSION: String = "1.0.0"
const MAX_BYTES: int = 4194304
const MAX_EVENTS: int = 4096
const MAX_TICKS: int = 216000
const GO_CODE_KIND: String = "go_code"
const OVERRIDE_KIND: String = "override"

var manifest_format: String = MANIFEST_FORMAT
var schema_version: int = SCHEMA_VERSION
var app_version: String = APP_VERSION
var map_id: String = ""
var map_sha256: String = ""
var initial_tick: int = 0
var terminal_tick: int = 0
var initial_snapshot: Dictionary = {}
var input_stream: Array[Dictionary] = []
var final_state_hash: String = ""
var journal_digest: String = ""
var integrity_hash: String = ""


static func canonical(data: Variant) -> String:
	var t := typeof(data)
	if t == TYPE_DICTIONARY:
		var keys: Array[String] = []
		for k in (data as Dictionary).keys():
			keys.append(String(k))
		keys.sort()
		var parts: Array[String] = []
		for k in keys:
			parts.append("%s:%s" % [JSON.stringify(k, "", true, true), canonical((data as Dictionary)[k])])
		return "{%s}" % ",".join(parts)
	if t == TYPE_ARRAY:
		var parts: Array[String] = []
		for item in data:
			parts.append(canonical(item))
		return "[%s]" % ",".join(parts)
	if t == TYPE_INT:
		return str(int(data))
	if t == TYPE_FLOAT:
		var f := float(data)
		if is_finite(f) and f == floor(f) and absf(f) < 9007199254740992.0:
			return str(int(f))
		return JSON.stringify(f, "", true, true)
	if t == TYPE_BOOL:
		return "true" if bool(data) else "false"
	if t == TYPE_NIL:
		return "null"
	return JSON.stringify(data, "", true, true)


static func create(world: SimWorld, initial: MissionSnapshot, go_codes: Array, overrides: Array, p_map_id: String = "", p_app_version: String = APP_VERSION) -> ReplayManifest:
	var m := ReplayManifest.new()
	m.manifest_format = MANIFEST_FORMAT
	m.schema_version = SCHEMA_VERSION
	m.app_version = p_app_version
	m.map_id = p_map_id
	m.map_sha256 = canonical(initial.data.get("map", {})).sha256_text()
	m.initial_tick = initial.captured_tick
	m.terminal_tick = world.tick
	var snap := initial.data.duplicate(true)
	if snap.has("rng_state"):
		snap["rng_state"] = str(int(snap["rng_state"]))
	if snap.has("rng_seed"):
		snap["rng_seed"] = str(int(snap["rng_seed"]))
	m.initial_snapshot = snap
	var events: Array[Dictionary] = []
	var seq: int = 0
	for e in go_codes:
		if e is Dictionary:
			events.append({
				"kind": GO_CODE_KIND,
				"tick": int(e.get("t", 0)),
				"seq": seq,
				"code": String(e.get("code", "")),
			})
			seq += 1
	for e in overrides:
		var data: Dictionary = {}
		if e is OverrideCommand:
			data = (e as OverrideCommand).to_dict()
		elif e is Dictionary:
			data = (e as Dictionary).duplicate(true)
		else:
			continue
		events.append({
			"kind": OVERRIDE_KIND,
			"tick": int(data.get("tick", 0)),
			"seq": seq,
			"data": data,
		})
		seq += 1
	events.sort_custom(func(a, b):
		var ta := int(a.get("tick", 0))
		var tb := int(b.get("tick", 0))
		if ta != tb:
			return ta < tb
		return int(a.get("seq", 0)) < int(b.get("seq", 0))
	)
	m.input_stream = events
	m.final_state_hash = world.state_hash()
	m.journal_digest = canonical(world.journal).sha256_text()
	m.integrity_hash = m.compute_integrity()
	return m


func to_dict() -> Dictionary:
	var events: Array = []
	for e in input_stream:
		events.append(e.duplicate(true))
	return {
		"manifest_format": manifest_format,
		"schema_version": schema_version,
		"app_version": app_version,
		"map_id": map_id,
		"map_sha256": map_sha256,
		"initial_tick": initial_tick,
		"terminal_tick": terminal_tick,
		"initial_snapshot": initial_snapshot.duplicate(true),
		"input_stream": events,
		"final_state_hash": final_state_hash,
		"journal_digest": journal_digest,
		"integrity_hash": integrity_hash,
	}


static func from_dict(d: Dictionary) -> ReplayManifest:
	var m := ReplayManifest.new()
	m.manifest_format = String(d.get("manifest_format", MANIFEST_FORMAT))
	m.schema_version = int(d.get("schema_version", SCHEMA_VERSION))
	m.app_version = String(d.get("app_version", APP_VERSION))
	m.map_id = String(d.get("map_id", ""))
	m.map_sha256 = String(d.get("map_sha256", ""))
	m.initial_tick = int(d.get("initial_tick", 0))
	m.terminal_tick = int(d.get("terminal_tick", 0))
	var snap: Variant = d.get("initial_snapshot", {})
	if snap is Dictionary:
		var sd := (snap as Dictionary).duplicate(true)
		var typed_journal: Array[Dictionary] = []
		var jv: Variant = sd.get("journal", [])
		if jv is Array:
			for je in jv:
				if je is Dictionary:
					typed_journal.append(je as Dictionary)
		sd["journal"] = typed_journal
		m.initial_snapshot = sd
	else:
		m.initial_snapshot = {}
	var events: Variant = d.get("input_stream", [])
	if events is Array:
		for e in events:
			if e is Dictionary:
				var ev := (e as Dictionary).duplicate(true)
				if ev.has("tick"):
					ev["tick"] = int(ev["tick"])
				if ev.has("seq"):
					ev["seq"] = int(ev["seq"])
				if ev.has("data") and ev["data"] is Dictionary:
					var od := (ev["data"] as Dictionary).duplicate(true)
					od["tick"] = int(od.get("tick", 0))
					od["op_id"] = int(od.get("op_id", -1))
					od["move_dir_x"] = float(od.get("move_dir_x", 0.0))
					od["move_dir_y"] = float(od.get("move_dir_y", 0.0))
					od["aim_deg"] = float(od.get("aim_deg", 0.0))
					od["fire_pressed"] = bool(od.get("fire_pressed", false))
					od["use_slot"] = bool(od.get("use_slot", false))
					ev["data"] = od
				m.input_stream.append(ev)
	m.final_state_hash = String(d.get("final_state_hash", ""))
	m.journal_digest = String(d.get("journal_digest", ""))
	m.integrity_hash = String(d.get("integrity_hash", ""))
	return m


func compute_integrity() -> String:
	var d := to_dict()
	d.erase("integrity_hash")
	return canonical(d).sha256_text()


func integrity_ok() -> bool:
	return integrity_hash != "" and integrity_hash == compute_integrity()


static func _is_hash(value: String) -> bool:
	if value.length() != 64:
		return false
	for i in value.length():
		var ch := value.substr(i, 1).to_lower()
		if not ((ch >= "0" and ch <= "9") or (ch >= "a" and ch <= "f")):
			return false
	return true


static func safe_id(value: String) -> String:
	if value.is_empty() or value.length() > 64:
		return ""
	for i in value.length():
		var ch := value.substr(i, 1)
		var ok := (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-"
		if not ok:
			return ""
	return value


static func validate(d: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	if String(d.get("manifest_format", "")) != MANIFEST_FORMAT:
		reasons.append("manifest_format")
	if int(d.get("schema_version", 0)) != SCHEMA_VERSION:
		reasons.append("schema_version")
	if int(d.get("initial_tick", -1)) != 0:
		reasons.append("initial_tick")
	var terminal := int(d.get("terminal_tick", -1))
	if terminal < 1 or terminal > MAX_TICKS:
		reasons.append("terminal_tick")
	if not (d.get("initial_snapshot", null) is Dictionary):
		reasons.append("initial_snapshot")
	if not (d.get("input_stream", null) is Array):
		reasons.append("input_stream")
	if not _is_hash(String(d.get("final_state_hash", ""))):
		reasons.append("final_state_hash")
	if not _is_hash(String(d.get("journal_digest", ""))):
		reasons.append("journal_digest")
	if not _is_hash(String(d.get("integrity_hash", ""))):
		reasons.append("integrity_hash")
	var events: Array = d.get("input_stream", [])
	if events.size() > MAX_EVENTS:
		reasons.append("event_count")
	var seqs: Dictionary = {}
	for i in events.size():
		var e: Variant = events[i]
		if not (e is Dictionary):
			reasons.append("event_shape:%d" % i)
			continue
		var ev := e as Dictionary
		var t := int(ev.get("tick", 0))
		if t < 1 or t > terminal:
			reasons.append("event_tick:%d" % i)
		var seq := int(ev.get("seq", -1))
		if seqs.has(seq):
			reasons.append("duplicate_seq:%d" % seq)
		seqs[seq] = true
		var kind := String(ev.get("kind", ""))
		if kind == GO_CODE_KIND:
			if not SimConstants.GO_CODES.has(StringName(String(ev.get("code", "")))):
				reasons.append("go_code:%d" % i)
		elif kind == OVERRIDE_KIND:
			var od: Variant = ev.get("data", null)
			if not (od is Dictionary):
				reasons.append("override_shape:%d" % i)
				continue
			var data := od as Dictionary
			for key in ["tick", "op_id"]:
				if typeof(data.get(key, null)) != TYPE_INT:
					reasons.append("override_%s:%d" % [key, i])
			for key in ["move_dir_x", "move_dir_y", "aim_deg"]:
				var v: Variant = data.get(key, null)
				if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
					reasons.append("override_%s:%d" % [key, i])
			for key in ["fire_pressed", "use_slot"]:
				if typeof(data.get(key, null)) != TYPE_BOOL:
					reasons.append("override_%s:%d" % [key, i])
			if int(data.get("tick", 0)) != t:
				reasons.append("override_tick_mismatch:%d" % i)
		else:
			reasons.append("event_kind:%d" % i)
	return reasons
