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


func get_wall_segments() -> Array:
	var segs := []
	var faces := [
		[Vector2i(0, -1), Vector2(0.0, 0.0), Vector2(1.0, 0.0)],
		[Vector2i(0, 1), Vector2(0.0, 1.0), Vector2(1.0, 1.0)],
		[Vector2i(-1, 0), Vector2(0.0, 0.0), Vector2(0.0, 1.0)],
		[Vector2i(1, 0), Vector2(1.0, 0.0), Vector2(1.0, 1.0)],
	]
	for c in solid_cells.keys():
		if door_cells.has(c) and bool(door_open.get(c, false)):
			continue
		for f in faces:
			var nb: Vector2i = c + f[0]
			if not in_bounds(nb) or is_solid(nb):
				segs.append([f[1], f[2]])
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
	return {
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
	m.insertion_zones = d.get("insertion_zones", [])
	m.extraction_zones = d.get("extraction_zones", [])
	m.defender_zones = d.get("defender_zones", [])
	m.objectives = d.get("objectives", [])
	m.ai_spawns = d.get("ai_spawns", [])
	m.hostage_spawns = d.get("hostage_spawns", [])
	m.jammer_nodes = d.get("jammer_nodes", [])
	return m
