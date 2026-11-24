# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name GreyboxMap
extends RefCounted

var width_cells := 16
var height_cells := 12
var solid_cells := {}
var door_cells := {}
var door_open := {}
var door_states := {}
var wall_materials := {}
var insertion_zones := []
var extraction_zones := []
var defender_zones := []
var objectives := []
var ai_spawns := []
var hostage_spawns := []
var jammer_nodes := []


static func build_default() -> GreyboxMap:
	var m := GreyboxMap.new()
	m.width_cells = 16
	m.height_cells = 12
	for x in range(m.width_cells):
		m.solid_cells[Vector2i(x, 0)] = true
		m.solid_cells[Vector2i(x, m.height_cells - 1)] = true
	for y in range(m.height_cells):
		m.solid_cells[Vector2i(0, y)] = true
		m.solid_cells[Vector2i(m.width_cells - 1, y)] = true
	for y in range(m.height_cells):
		if y != 6:
			m.solid_cells[Vector2i(8, y)] = true
	m.door_cells[Vector2i(8, 6)] = true
	m.door_open[Vector2i(8, 6)] = false
	m.door_states[Vector2i(8, 6)] = &"CLOSED_UNLOCKED"
	return m


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width_cells and cell.y < height_cells


func is_solid(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return true
	if door_cells.has(cell):
		return not bool(door_open.get(cell, false))
	return solid_cells.has(cell)


func open_door(cell: Vector2i) -> void:
	if door_cells.has(cell):
		door_open[cell] = true
		if door_states.has(cell) and door_states[cell] != &"BREACHED_DESTROYED":
			door_states[cell] = &"OPEN"


func door_state(cell: Vector2i) -> StringName:
	if not door_cells.has(cell):
		return &""
	if door_states.has(cell):
		return door_states[cell]
	return &"OPEN" if bool(door_open.get(cell, false)) else &"CLOSED_UNLOCKED"


func occludes(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return true
	return is_solid(cell)


func get_wall_segments() -> Array:
	var segs := []
	var w := width_cells
	var h := height_cells
	for y in range(1, h):
		var run := -1
		for x in range(w + 1):
			var edge := x < w and occludes(Vector2i(x, y - 1)) != occludes(Vector2i(x, y))
			if edge and run < 0:
				run = x
			elif not edge and run >= 0:
				segs.append([Vector2(run, y), Vector2(x, y)])
				run = -1
	for x in range(1, w):
		var run := -1
		for y in range(h + 1):
			var edge := y < h and occludes(Vector2i(x - 1, y)) != occludes(Vector2i(x, y))
			if edge and run < 0:
				run = y
			elif not edge and run >= 0:
				segs.append([Vector2(x, run), Vector2(x, y)])
				run = -1
	segs.append([Vector2(0, 0), Vector2(w, 0)])
	segs.append([Vector2(w, 0), Vector2(w, h)])
	segs.append([Vector2(w, h), Vector2(0, h)])
	segs.append([Vector2(0, h), Vector2(0, 0)])
	return segs


static func load_from_json(path: String) -> GreyboxMap:
	return MapLoader.load_from_json(path)


static func load_from_string(text: String) -> GreyboxMap:
	return MapLoader.load_from_string(text)


func to_dict() -> Dictionary:
	var solids: Array = []
	for k in solid_cells.keys():
		solids.append([int(k.x), int(k.y)])
	var doors: Array = []
	for k in door_cells.keys():
		doors.append([int(k.x), int(k.y)])
	var opens: Array = []
	for k in door_open.keys():
		opens.append([int(k.x), int(k.y), bool(door_open[k])])
	var states: Array = []
	for k in door_states.keys():
		states.append([int(k.x), int(k.y), String(door_states[k])])
	var mats: Array = []
	for k in wall_materials.keys():
		mats.append([int(k.x), int(k.y), String(wall_materials[k])])
	return {
		"door_states": states,
		"wall_materials": mats,
		"w": width_cells,
		"h": height_cells,
		"solids": solids,
		"door_cells": doors,
		"door_open": opens,
		"insertion_zones": insertion_zones,
		"extraction_zones": extraction_zones,
		"defender_zones": defender_zones,
		"objectives": objectives,
		"ai_spawns": ai_spawns,
		"hostage_spawns": hostage_spawns,
		"jammer_nodes": jammer_nodes,
	}


static func from_dict(d: Dictionary) -> GreyboxMap:
	var m := GreyboxMap.new()
	m.width_cells = int(d.get("w", 16))
	m.height_cells = int(d.get("h", 12))
	for s in d.get("solids", []):
		m.solid_cells[Vector2i(int(s[0]), int(s[1]))] = true
	for dc in d.get("door_cells", []):
		m.door_cells[Vector2i(int(dc[0]), int(dc[1]))] = true
	for os in d.get("door_open", []):
		m.door_open[Vector2i(int(os[0]), int(os[1]))] = bool(os[2])
	for st in d.get("door_states", []):
		m.door_states[Vector2i(int(st[0]), int(st[1]))] = StringName(String(st[2]))
	for mt in d.get("wall_materials", []):
		m.wall_materials[Vector2i(int(mt[0]), int(mt[1]))] = StringName(String(mt[2]))
	m.insertion_zones = d.get("insertion_zones", [])
	m.extraction_zones = d.get("extraction_zones", [])
	m.defender_zones = d.get("defender_zones", [])
	m.objectives = d.get("objectives", [])
	m.ai_spawns = d.get("ai_spawns", [])
	m.hostage_spawns = d.get("hostage_spawns", [])
	m.jammer_nodes = d.get("jammer_nodes", [])
	return m
