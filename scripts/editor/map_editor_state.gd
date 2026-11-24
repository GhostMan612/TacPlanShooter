# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name MapEditorState
extends RefCounted


enum Tool { WALL, DOOR, STAIR, ZONES, UNITS, ERASE, UNDO, REDO, VALIDATE, PLAYTEST, EXPORT, IMPORT }


var map: GreyboxMap = GreyboxMap.new()
var current_tool: int = Tool.WALL
var action_stack_limit: int = 50
var _actions: Array = []
var _redo_stack: Array = []


func _push(undo_f: Callable, redo_f: Callable) -> void:
	_redo_stack.clear()
	var a := {"undo": undo_f, "redo": redo_f}
	_actions.push_back(a)
	if _actions.size() > action_stack_limit:
		_actions.pop_front()


func _apply_wall(c: Vector2i, was_solid: bool) -> void:
	if was_solid:
		map.solid_cells[c] = true
	else:
		map.solid_cells.erase(c)
		map.door_cells.erase(c)


func paint_wall(c: Vector2i) -> void:
	var was_solid: bool = map.solid_cells.has(c)
	_push(Callable(self, "_apply_wall").bind(c, was_solid), Callable(self, "_paint_wall").bind(c))
	map.solid_cells[c] = true
	map.door_cells.erase(c)
	map.door_open.erase(c)


func _paint_wall(c: Vector2i) -> void:
	map.solid_cells[c] = true


func _apply_door(c: Vector2i, had: bool) -> void:
	if had:
		map.door_cells[c] = true
		map.door_open[c] = true
	else:
		map.door_cells.erase(c)
		map.door_open.erase(c)


func _paint_door(c: Vector2i) -> void:
	map.door_cells[c] = true
	map.door_open[c] = true


func paint_door(c: Vector2i) -> void:
	var had: bool = map.door_cells.has(c)
	_push(Callable(self, "_apply_door").bind(c, had), Callable(self, "_paint_door").bind(c))
	map.door_cells[c] = true
	map.door_open[c] = true


func paint_zone(ztype: StringName, cells: Array) -> void:
	_push(Callable(self, "_apply_zone").bind(ztype, cells, false), Callable(self, "_apply_zone").bind(ztype, cells, true))
	var arr := _zone_arr(ztype, cells)
	_zone_list(map, ztype).append(arr)


func _apply_zone(ztype: StringName, cells: Array, added: bool) -> void:
	var arr := _zone_arr(ztype, cells)
	var lst := _zone_list(map, ztype)
	if added:
		lst.append(arr)
	else:
		for z in lst:
			if z == arr:
				lst.erase(z)
				return


func _zone_arr(ztype: StringName, cells: Array) -> Dictionary:
	var cl: Array = []
	for c in cells:
		cl.append([int(c[0]), int(c[1])])
	return {"type": ztype, "cells": cl}


func _zone_list(m: GreyboxMap, ztype: StringName) -> Array:
	if ztype == &"INSERTION":
		return m.insertion_zones
	if ztype == &"EXTRACTION":
		return m.extraction_zones
	return m.defender_zones


func _apply_ai_spawn(c: Vector2i, archetype: StringName) -> void:
	var lst: Array = []
	for s in map.ai_spawns:
		if Vector2i(int(s["cell"][0]), int(s["cell"][1])) != c:
			lst.append(s)
	map.ai_spawns = lst


func _paint_ai_spawn(c: Vector2i, archetype: StringName) -> void:
	map.ai_spawns.append({"cell": [int(c.x), int(c.y)], "archetype": archetype})


func place_ai_spawn(c: Vector2i, archetype: StringName) -> void:
	_push(Callable(self, "_apply_ai_spawn").bind(c, archetype), Callable(self, "_paint_ai_spawn").bind(c, archetype))
	_paint_ai_spawn(c, archetype)


func _apply_objective(c: Vector2i) -> void:
	for o in map.objectives:
		if Vector2i(int(o["cell"][0]), int(o["cell"][1])) == c:
			map.objectives.erase(o)
			return


func _paint_objective(c: Vector2i) -> void:
	map.objectives.append({"cell": [int(c.x), int(c.y)], "id": str(map.objectives.size() + 1)})


func place_objective(c: Vector2i) -> void:
	_push(Callable(self, "_apply_objective").bind(c), Callable(self, "_paint_objective").bind(c))
	_paint_objective(c)


func _apply_jammer(c: Vector2i) -> void:
	map.jammer_nodes.erase([int(c.x), int(c.y)])


func _paint_jammer(c: Vector2i) -> void:
	map.jammer_nodes.append([int(c.x), int(c.y)])


func place_jammer(c: Vector2i) -> void:
	_push(Callable(self, "_apply_jammer").bind(c), Callable(self, "_paint_jammer").bind(c))
	_paint_jammer(c)


func validate() -> Array:
	return MapEditorValidator.validate(map)


func to_json() -> String:
	return JSON.stringify(map.to_dict())


static func from_json(text: String) -> MapEditorState:
	var st := MapEditorState.new()
	st.map = MapLoader.load_from_string(text)
	return st


func snapshot_cell(c: Vector2i) -> Dictionary:
	return {
		"solid": map.solid_cells.has(c),
		"door": map.door_cells.has(c),
		"door_open": bool(map.door_open.get(c, false)),
		"objectives": _without_cell(map.objectives, c, true),
		"ai_spawns": _without_cell(map.ai_spawns, c, true),
		"hostage_spawns": _without_cell(map.hostage_spawns, c, true),
		"jammer_nodes": _without_cell(map.jammer_nodes, c, true),
		"insertion_zones": map.insertion_zones.duplicate(true),
		"extraction_zones": map.extraction_zones.duplicate(true),
		"defender_zones": map.defender_zones.duplicate(true),
	}


func cell_has_content(c: Vector2i) -> bool:
	if map.solid_cells.has(c) or map.door_cells.has(c):
		return true
	for lst in [map.objectives, map.ai_spawns, map.hostage_spawns, map.jammer_nodes]:
		if not _matching(lst, c).is_empty():
			return true
	for lst in [map.insertion_zones, map.extraction_zones, map.defender_zones]:
		for z in lst:
			for zc in z.get("cells", []):
				if MapEditorValidator.cell_of(zc) == c:
					return true
	return false


func erase_cell(c: Vector2i) -> bool:
	if not cell_has_content(c):
		return false
	var before := snapshot_cell(c)
	_push(Callable(self, "_restore_cell").bind(c, before), Callable(self, "_clear_cell").bind(c))
	_clear_cell(c)
	return true


func _clear_cell(c: Vector2i) -> void:
	map.solid_cells.erase(c)
	map.door_cells.erase(c)
	map.door_open.erase(c)
	map.objectives = _without_cell(map.objectives, c, false)
	map.ai_spawns = _without_cell(map.ai_spawns, c, false)
	map.hostage_spawns = _without_cell(map.hostage_spawns, c, false)
	map.jammer_nodes = _without_cell(map.jammer_nodes, c, false)
	map.insertion_zones = _zones_without_cell(map.insertion_zones, c)
	map.extraction_zones = _zones_without_cell(map.extraction_zones, c)
	map.defender_zones = _zones_without_cell(map.defender_zones, c)


func _restore_cell(c: Vector2i, before: Dictionary) -> void:
	if bool(before["solid"]):
		map.solid_cells[c] = true
	if bool(before["door"]):
		map.door_cells[c] = true
		map.door_open[c] = bool(before["door_open"])
	map.objectives = map.objectives + before["objectives"]
	map.ai_spawns = map.ai_spawns + before["ai_spawns"]
	map.hostage_spawns = map.hostage_spawns + before["hostage_spawns"]
	map.jammer_nodes = map.jammer_nodes + before["jammer_nodes"]
	map.insertion_zones = before["insertion_zones"].duplicate(true)
	map.extraction_zones = before["extraction_zones"].duplicate(true)
	map.defender_zones = before["defender_zones"].duplicate(true)


func _matching(lst: Array, c: Vector2i) -> Array:
	var out := []
	for e in lst:
		if MapEditorValidator.cell_of(e) == c:
			out.append(e)
	return out


func _without_cell(lst: Array, c: Vector2i, invert: bool) -> Array:
	var out := []
	for e in lst:
		var hit := MapEditorValidator.cell_of(e) == c
		if hit == invert:
			out.append(e)
	return out


func _zones_without_cell(zones: Array, c: Vector2i) -> Array:
	var out := []
	for z in zones:
		var cells := []
		for zc in z.get("cells", []):
			if MapEditorValidator.cell_of(zc) != c:
				cells.append(zc)
		if cells.is_empty():
			continue
		var nz: Dictionary = z.duplicate(true)
		nz["cells"] = cells
		out.append(nz)
	return out


func undo() -> void:
	if _actions.is_empty():
		return
	var a: Dictionary = _actions.pop_back()
	a["undo"].call()
	_redo_stack.push_back(a)


func redo() -> void:
	if _redo_stack.is_empty():
		return
	var a: Dictionary = _redo_stack.pop_back()
	a["redo"].call()
	_actions.push_back(a)
