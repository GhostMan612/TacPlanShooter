# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name ScreenRouter
extends RefCounted


enum Stage { SPLASH, TITLE, LOADING, PREP, IN_MISSION, AAR, CAMPAIGN, SETTINGS, HQ, CREDITS, MAP_EDITOR }


signal advanced(stage: int)


const PARAMS_META := "tacplan_router_params"
const DEFAULT_MAP_PATH := "res://data/maps/op01_glass_house.json"


var stage := int(Stage.SPLASH)


static func scene_for(s: int) -> String:
	match s:
		Stage.SPLASH:
			return "res://scenes/splash.tscn"
		Stage.TITLE:
			return "res://scenes/title.tscn"
		Stage.LOADING:
			return "res://scenes/loading.tscn"
		Stage.PREP, Stage.IN_MISSION:
			return "res://scenes/planning.tscn"
		Stage.AAR:
			return "res://scenes/aar.tscn"
		Stage.CAMPAIGN:
			return "res://scenes/campaign.tscn"
		Stage.SETTINGS:
			return "res://scenes/settings.tscn"
		Stage.HQ:
			return "res://scenes/hq.tscn"
		Stage.CREDITS:
			return "res://scenes/credits.tscn"
		Stage.MAP_EDITOR:
			return "res://scenes/map_editor.tscn"
	return ""


static func goto_stage(s: int) -> bool:
	var path := scene_for(s)
	if path == "":
		return false
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	return tree.change_scene_to_file(path) == OK


static func _params() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return {}
	if not tree.root.has_meta(PARAMS_META):
		tree.root.set_meta(PARAMS_META, {})
	var d: Dictionary = tree.root.get_meta(PARAMS_META)
	return d


static func set_param(key: String, value: Variant) -> void:
	var d := _params()
	d[key] = value
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.set_meta(PARAMS_META, d)


static func get_param(key: String, fallback: Variant = null) -> Variant:
	var d := _params()
	return d.get(key, fallback)


static func clear_param(key: String) -> void:
	var d := _params()
	d.erase(key)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.set_meta(PARAMS_META, d)


func to_scene(s: int) -> void:
	stage = s
	goto_stage(s)


func advance() -> void:
	if stage < int(Stage.AAR):
		stage += 1
	advanced.emit(stage)
