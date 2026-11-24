# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
extends Node


const SCRIPT_ROOTS: Array[String] = ["res://scripts", "res://tests"]
const SCENE_ROOTS: Array[String] = ["res://scenes", "res://tests"]
const SELF_PATH := "res://tests/parse_all.gd"


func _ready() -> void:
	print("[PARSE_ALL] begin")
	var failures := 0
	var scripts: Array[String] = []
	for r in SCRIPT_ROOTS:
		_collect(r, ".gd", scripts)
	scripts.sort()
	for path in scripts:
		if path == SELF_PATH:
			continue
		var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		var scr := res as Script
		var ok := scr != null and scr.can_instantiate()
		if not ok:
			failures += 1
		print("[PARSE_ALL] %s script %s" % ["OK" if ok else "FAIL", path])
		if not ok:
			_diagnose(path)
	var scenes: Array[String] = []
	for r in SCENE_ROOTS:
		_collect(r, ".tscn", scenes)
	scenes.sort()
	for path in scenes:
		var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		var packed := res as PackedScene
		var ok := packed != null and packed.can_instantiate()
		if ok:
			var state := packed.get_state()
			ok = state.get_node_count() > 0 and state.get_node_property_count(0) > 0
		if not ok:
			failures += 1
		print("[PARSE_ALL] %s scene %s" % ["OK" if ok else "FAIL", path])
	print("[PARSE_ALL] RESULT %s scripts=%d scenes=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", scripts.size() - 1, scenes.size(), failures])
	get_tree().quit(1 if failures > 0 else 0)


func _collect(dir_path: String, ext: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		var full := dir_path + "/" + entry
		if d.current_is_dir():
			if not entry.begins_with("."):
				_collect(full, ext, out)
		elif entry.ends_with(ext):
			out.append(full)
		entry = d.get_next()
	d.list_dir_end()


func _diagnose(path: String) -> void:
	var probe := GDScript.new()
	probe.source_code = FileAccess.get_file_as_string(path)
	var err := probe.reload()
	print("[PARSE_ALL] diagnose %s reload_error=%d (parser errors print above with line numbers)" % [path, err])
