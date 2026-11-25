# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name PropsPlacement
extends Node2D


const MAX_UNITS: int = 48
var map: GreyboxMap = null
var mm: MultiMesh = null
var mesh: MeshInstance2D = null
var color_map: Dictionary = {}
var placed_cells: Array = []


func setup(m: GreyboxMap) -> void:
	map = m
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.multimesh_format_version = 1
	mm.instance_count = 0
	mesh = MeshInstance2D.new()
	mesh.multimesh = mm
	add_child(mesh)
	_build_colors()


func _build_colors() -> void:
	color_map[&"patrol_sentry"] = Color(0.3, 0.8, 1.0)
	color_map[&"breacher"] = Color(0.9, 0.6, 0.3)
	color_map[&"flanker"] = Color(0.7, 0.35, 0.9)
	color_map[&"tower"] = Color(0.9, 0.9, 0.2)
	color_map[&"defender"] = Color(1.0, 0.5, 0.5)


func rebuild() -> void:
	var n := 0
	if mm != null:
		for e in map.ai_spawns:
			if n < MAX_UNITS and not map.is_solid(Vector2i(int(e["cell"][0]), int(e["cell"][1]))):
				n += 1
		for z in map.defender_zones:
			for c in z["cells"]:
				if n < MAX_UNITS and not map.is_solid(Vector2i(int(c[0]), int(c[1]))):
					n += 1
	if mm != null:
		mm.instance_count = n
	placed_cells = []
	if mm != null:
		var i := 0
		for e in map.ai_spawns:
			var t: Transform2D = Transform2D.new()
			t.translate(Vector2(float(e["cell"][0]) + 0.5, float(e["cell"][1]) + 0.5) * float(SimConstants.GRID_CELL_SIZE_PX))
			mm.set_instance_transform_2d(i, t)
			mm.set_instance_color(i, color_map.get(StringName(String(e.get("archetype", ""))), Color.WHITE))
			i += 1
		for z in map.defender_zones:
			for c in z["cells"]:
				if i < MAX_UNITS:
					var t2: Transform2D = Transform2D.new()
				t2.translate(Vector2(float(c[0]) + 0.5, float(c[1]) + 0.5) * float(SimConstants.GRID_CELL_SIZE_PX))
				mm.set_instance_transform_2d(i, t2)
					mm.set_instance_color(i, color_map[&"defender"])
					i += 1
		while i < mm.instance_count:
			mm.set_instance_transform_2d(i, Transform2D())
			i += 1


func add_unit(cell: Vector2i, archetype: StringName) -> void:
	if map != null and not map.is_solid(cell) and map.ai_spawns.size() < MAX_UNITS:
		map.ai_spawns.append({"cell": [int(cell.x), int(cell.y)], "archetype": archetype})
		rebuild()


func rebuild_legacy() -> void:
	pass
