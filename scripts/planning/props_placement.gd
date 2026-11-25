# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name PropsPlacement
extends Node2D


const MAX_UNITS: int = 48
var map: GreyboxMap = null
var mm: MultiMesh = null
var multimesh_node: MultiMeshInstance2D = null
var color_map: Dictionary = {}
var placed_cells: Array[Vector2i] = []


func setup(m: GreyboxMap) -> void:
	map = m
	if multimesh_node != null:
		remove_child(multimesh_node)
		multimesh_node.queue_free()
		multimesh_node = null
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	var qm := QuadMesh.new()
	qm.size = Vector2(6.0, 6.0)
	mm.mesh = qm
	mm.instance_count = 0
	multimesh_node = MultiMeshInstance2D.new()
	multimesh_node.multimesh = mm
	add_child(multimesh_node)
	_build_colors()
	rebuild()


func _build_colors() -> void:
	color_map[&"patrol_sentry"] = Color(0.3, 0.8, 1.0)
	color_map[&"breacher"] = Color(0.9, 0.6, 0.3)
	color_map[&"tactical_flanker"] = Color(0.7, 0.35, 0.9)
	color_map[&"room_anchor"] = Color(0.9, 0.55, 0.25)
	color_map[&"heavy_gunner"] = Color(0.95, 0.35, 0.35)
	color_map[&"hostage_guard"] = Color(0.95, 0.75, 0.2)
	color_map[&"tech_jammer"] = Color(0.75, 0.45, 0.95)
	color_map[&"defender"] = Color(1.0, 0.5, 0.5)


func rebuild() -> void:
	placed_cells.clear()
	if map == null or mm == null:
		return
	var entries: Array[Dictionary] = []
	for e in map.ai_spawns:
		var cell := CpuCommander._cell_from_entry(e)
		if entries.size() < MAX_UNITS and map.in_bounds(cell) and not map.is_solid(cell):
			var arch := StringName(String(e.get("archetype", "patrol_sentry"))) if typeof(e) == TYPE_DICTIONARY else &"patrol_sentry"
			entries.append({"cell": cell, "color": color_map.get(arch, Color.WHITE)})
	for z in map.defender_zones:
		if typeof(z) != TYPE_DICTIONARY:
			continue
		for raw_c in z.get("cells", []):
			var cell := CpuCommander._cell_from_entry(raw_c)
			if entries.size() < MAX_UNITS and map.in_bounds(cell) and not map.is_solid(cell):
				entries.append({"cell": cell, "color": color_map[&"defender"]})
	mm.instance_count = entries.size()
	for i in range(entries.size()):
		var cell: Vector2i = entries[i]["cell"]
		var col: Color = entries[i]["color"]
		var xf := Transform2D(0.0, GridUtil.cell_center_px(cell))
		mm.set_instance_transform_2d(i, xf)
		mm.set_instance_color(i, col)
		placed_cells.append(cell)


func add_unit(cell: Vector2i, archetype: StringName) -> void:
	if map != null and not map.is_solid(cell) and map.ai_spawns.size() < MAX_UNITS:
		map.ai_spawns.append({"cell": [int(cell.x), int(cell.y)], "archetype": String(archetype)})
		rebuild()
