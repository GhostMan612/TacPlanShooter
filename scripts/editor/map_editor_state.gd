# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name MapEditorState
extends RefCounted


enum Tool { WALL, DOOR, STAIR, ZONES, UNITS, ERASE, UNDO, REDO, VALIDATE, PLAYTEST, EXPORT, IMPORT }

const GEOMETRY_FIELDS := [&"solid_cells", &"door_cells", &"door_open", &"door_states", &"wall_materials"]
const POINT_FIELDS := [&"objectives", &"ai_spawns", &"hostage_spawns", &"jammer_nodes"]
const ZONE_FIELDS := [&"insertion_zones", &"extraction_zones", &"defender_zones"]


var map: GreyboxMap = GreyboxMap.new()
var current_tool: int = Tool.WALL
var action_stack_limit: int = 50
var _actions: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []


func _push(undo_f: Callable, redo_f: Callable) -> void:
	_redo_stack.clear()
	_actions.push_back({"undo": undo_f, "redo": redo_f})
	if _actions.size() > action_stack_limit:
		_actions.pop_front()


func _geometry_at(c: Vector2i) -> Dictionary:
	var before := {}
	for field in GEOMETRY_FIELDS:
		var entries: Dictionary = map.get(field)
		if entries.has(c):
			before[field] = entries[c]
	return before


func _set_geometry(c: Vector2i, data: Dictionary) -> void:
	for field in GEOMETRY_FIELDS:
		var entries: Dictionary = map.get(field)
		if data.has(field):
			entries[c] = data[field]
		else:
			entries.erase(c)


func _edit_geometry(c: Vector2i, before: Dictionary, after: Dictionary) -> void:
	_push(Callable(self, "_set_geometry").bind(c, before), Callable(self, "_set_geometry").bind(c, after))
	_set_geometry(c, after)


func paint_wall(c: Vector2i) -> void:
	var before := _geometry_at(c)
	var after := {&"solid_cells": true}
	if before.has(&"wall_materials"):
		after[&"wall_materials"] = before[&"wall_materials"]
	_edit_geometry(c, before, after)


func paint_door(c: Vector2i) -> void:
	var before := _geometry_at(c)
	var after := before.duplicate()
	after[&"door_cells"] = true
	after[&"door_open"] = true
	after[&"door_states"] = &"OPEN"
	_edit_geometry(c, before, after)


func _add_entry(entries: Array, value: Variant) -> void:
	entries.append(value)


func _remove_entry(entries: Array, index: int) -> void:
	entries.remove_at(index)


func _record_append(entries: Array, value: Variant) -> void:
	_push(Callable(self, "_remove_entry").bind(entries, entries.size()), Callable(self, "_add_entry").bind(entries, value))
	_add_entry(entries, value)


func paint_zone(ztype: StringName, cells: Array) -> void:
	var zone_cells: Array = []
	for c in cells:
		zone_cells.append([int(c[0]), int(c[1])])
	var zones := map.defender_zones
	if ztype == &"INSERTION":
		zones = map.insertion_zones
	elif ztype == &"EXTRACTION":
		zones = map.extraction_zones
	_record_append(zones, {"type": ztype, "cells": zone_cells})


func place_ai_spawn(c: Vector2i, archetype: StringName) -> void:
	_record_append(map.ai_spawns, {"cell": [c.x, c.y], "archetype": archetype})


func place_objective(c: Vector2i) -> void:
	var used := {}
	for entry in map.objectives:
		used[str(entry.get("id", ""))] = true
	var id := map.objectives.size() + 1
	while used.has(str(id)):
		id += 1
	_record_append(map.objectives, {"cell": [c.x, c.y], "id": str(id)})


func place_jammer(c: Vector2i) -> void:
	_record_append(map.jammer_nodes, [c.x, c.y])


func validate() -> Array:
	return MapEditorValidator.validate(map)


func to_json() -> String:
	return JSON.stringify(map.to_dict())


static func from_json(text: String) -> MapEditorState:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY or not MapEditorValidator.has_import_shape(parsed):
		return null
	var st := MapEditorState.new()
	st.map = MapLoader.from_data(parsed)
	return st


func cell_has_content(c: Vector2i) -> bool:
	if not _geometry_at(c).is_empty():
		return true
	for field in POINT_FIELDS:
		var entries: Array = map.get(field)
		for entry in entries:
			if MapEditorValidator.cell_of(entry) == c:
				return true
	for field in ZONE_FIELDS:
		var zones: Array = map.get(field)
		for zone in zones:
			for entry in zone.get("cells", []):
				if MapEditorValidator.cell_of(entry) == c:
					return true
	return false


func erase_cell(c: Vector2i) -> bool:
	if not cell_has_content(c):
		return false
	var geometry := _geometry_at(c)
	var before := {}
	for field in POINT_FIELDS + ZONE_FIELDS:
		var entries: Array = map.get(field)
		before[field] = entries.duplicate(true)
	_push(Callable(self, "_restore_cell").bind(c, geometry, before), Callable(self, "_clear_cell").bind(c))
	_clear_cell(c)
	return true


func _clear_cell(c: Vector2i) -> void:
	_set_geometry(c, {})
	for field in POINT_FIELDS:
		var entries: Array = map.get(field)
		entries.assign(_without_cell(entries, c))
	for field in ZONE_FIELDS:
		var zones: Array = map.get(field)
		zones.assign(_zones_without_cell(zones, c))


func _restore_cell(c: Vector2i, geometry: Dictionary, content: Dictionary) -> void:
	_set_geometry(c, geometry)
	for field in POINT_FIELDS + ZONE_FIELDS:
		var entries: Array = map.get(field)
		var original: Array = content[field]
		entries.assign(original.duplicate(true))


func _without_cell(entries: Array, c: Vector2i) -> Array:
	var out: Array = []
	for entry in entries:
		if MapEditorValidator.cell_of(entry) != c:
			out.append(entry)
	return out


func _zones_without_cell(zones: Array, c: Vector2i) -> Array:
	var out: Array = []
	for zone in zones:
		var cells: Array = zone.get("cells", [])
		var remaining := _without_cell(cells, c)
		if remaining.size() == cells.size():
			out.append(zone)
		elif not remaining.is_empty():
			var changed: Dictionary = zone.duplicate()
			changed["cells"] = remaining
			out.append(changed)
	return out


func undo() -> void:
	if _actions.is_empty():
		return
	var action: Dictionary = _actions.pop_back()
	action["undo"].call()
	_redo_stack.push_back(action)


func redo() -> void:
	if _redo_stack.is_empty():
		return
	var action: Dictionary = _redo_stack.pop_back()
	action["redo"].call()
	_actions.push_back(action)
