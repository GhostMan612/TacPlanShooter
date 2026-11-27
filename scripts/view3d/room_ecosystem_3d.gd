# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name RoomEcosystem3D
extends Node3D


const CELL_UNITS: float = 1.5
const FLOOR_RISE: float = 3.2
enum Archetype { OFFICE, SERVER_ROOM, CORRIDOR, STORAGE, SECURITY, COURTYARD }

var rooms: Dictionary = {}
var prop_count: int = 0
var _box: BoxMesh = null


func build(m: GreyboxMap, floor: int) -> void:
	rooms.clear()
	prop_count = 0
	_box = BoxMesh.new()
	var visited := {}
	for y in range(1, m.height_cells - 1):
		for x in range(1, m.width_cells - 1):
			var c := Vector2i(x, y)
			if m.is_solid(c) or visited.has(c):
				continue
			var cells := _flood(m, c, visited)
			var archetype := _classify(cells)
			var center := Vector2.ZERO
			for cell in cells:
				center += Vector2(cell)
			center /= float(maxi(1, cells.size()))
			rooms[center] = {"archetype": archetype, "cells": cells}
			_populate(m, floor, cells, archetype)


func _flood(m: GreyboxMap, start: Vector2i, visited: Dictionary) -> Array:
	var out: Array = []
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		out.append(c)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if m.in_bounds(n) and not m.is_solid(n) and not visited.has(n):
				visited[n] = true
				queue.append(n)
	return out


func _classify(cells: Array) -> int:
	if cells.size() > 90:
		return int(Archetype.COURTYARD)
	var h: int = 0
	for c in cells:
		h ^= (c.x * 73856093) ^ (c.y * 19349663)
	match posmod(h, 5):
		0: return int(Archetype.OFFICE)
		1: return int(Archetype.SERVER_ROOM)
		2: return int(Archetype.CORRIDOR)
		3: return int(Archetype.STORAGE)
		_: return int(Archetype.SECURITY)


func _populate(m: GreyboxMap, floor: int, cells: Array, archetype: int) -> void:
	var count := 0
	for c in cells:
		var h: int = (c.x * 73856093) ^ (c.y * 19349663)
		if (h & 3) != 0:
			continue
		var inst := MeshInstance3D.new()
		inst.mesh = _box
		var mat := StandardMaterial3D.new()
		match archetype:
			int(Archetype.SERVER_ROOM):
				mat.albedo_color = Color(0.08, 0.14, 0.20)
				mat.emission_enabled = true
				mat.emission = Color(0.1, 0.9, 0.85)
				mat.emission_energy_multiplier = 0.5
				inst.scale = Vector3(0.6, 1.5, 0.6)
			int(Archetype.OFFICE):
				mat.albedo_color = Color(0.32, 0.26, 0.18)
				inst.scale = Vector3(1.1, 0.5, 0.6)
			int(Archetype.STORAGE):
				mat.albedo_color = Color(0.36, 0.28, 0.20)
				inst.scale = Vector3(0.7, 0.7, 0.7)
			int(Archetype.CORRIDOR):
				mat.albedo_color = Color(0.18, 0.22, 0.26)
				inst.scale = Vector3(1.2, 0.08, 0.3)
			_:
				mat.albedo_color = Color(0.25, 0.30, 0.36)
				inst.scale = Vector3(0.8, 0.9, 0.5)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		inst.material_override = mat
		inst.position = cell_to_world(c, floor) + Vector3(0.0, inst.scale.y * 0.5, 0.0)
		add_child(inst)
		count += 1
	prop_count += count


static func cell_to_world(c: Vector2i, floor: int) -> Vector3:
	return Vector3(float(c.x) * CELL_UNITS, float(floor) * FLOOR_RISE, float(c.y) * CELL_UNITS)

