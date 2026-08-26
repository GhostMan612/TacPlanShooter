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


func is_solid(cell: Vector2i) -> bool:
	if door_cells.has(cell):
		return not bool(door_open[cell])
	return solid_cells.has(cell)


func open_door(cell: Vector2i) -> void:
	door_open[cell] = true


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
	return m
