# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name Route3DOverlay
extends Node3D


const CELL_UNITS: float = 1.5
const FLOOR_RISE: float = 3.2
var SQUAD_COLORS: Dictionary = {
	&"red": Color.html("#EF4444"),
	&"blue": Color.html("#3B82F6"),
	&"green": Color.html("#22C55E"),
	&"gold": Color.html("#F59E0B"),
}
const GO_COLORS: Array[Color] = [Color(1.0, 0.75, 0.1), Color(0.2, 0.9, 0.5), Color(0.2, 0.75, 1.0), Color(1.0, 0.3, 0.25)]


var routes: Dictionary = {}
var active_floor: int = 0
var _ribbon: MeshInstance3D = null
var _nodes: Node3D = null
var _beacons: Node3D = null
var _line_material: StandardMaterial3D = null
var _sphere: SphereMesh = null
var _box: BoxMesh = null


func _ready() -> void:
	_line_material = StandardMaterial3D.new()
	_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_material.emission_enabled = true
	_line_material.emission = Color.WHITE
	_ribbon = MeshInstance3D.new()
	_ribbon.name = "RouteRibbons"
	_ribbon.mesh = ImmediateMesh.new()
	_ribbon.material_override = _line_material
	add_child(_ribbon)
	_nodes = Node3D.new()
	_nodes.name = "Waypoints"
	add_child(_nodes)
	_beacons = Node3D.new()
	_beacons.name = "GoCodeBeacons"
	add_child(_beacons)
	_sphere = SphereMesh.new()
	_sphere.radius = 0.16
	_sphere.height = 0.32
	_box = BoxMesh.new()


func set_routes(src: Dictionary, floor: int) -> void:
	routes = src.duplicate(true)
	active_floor = floor
	_rebuild()


func _rebuild() -> void:
	if _ribbon == null:
		return
	for child in _nodes.get_children():
		child.free()
	for child in _beacons.get_children():
		child.free()
	var lines := ImmediateMesh.new()
	var added := false
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	var idx := 0
	for key in routes.keys():
		var cells: Array = routes[key]
		var col: Color = SQUAD_COLORS.get(key if key is StringName else StringName(str(key)), Color.WHITE)
		if cells.size() < 2:
			continue
		var i := 0
		while i < cells.size() - 1:
			var a: Vector2i = cells[i]
			var b: Vector2i = cells[i + 1]
			var y := float(active_floor) * FLOOR_RISE + 0.08
			lines.surface_set_color(col)
			lines.surface_add_vertex(Vector3(float(a.x) * CELL_UNITS + 0.75, y, float(a.y) * CELL_UNITS + 0.75))
			lines.surface_add_vertex(Vector3(float(b.x) * CELL_UNITS + 0.75, y, float(b.y) * CELL_UNITS + 0.75))
			added = true
			i += 1
		var last: Vector2i = cells[cells.size() - 1]
		_add_node(last, col, idx + 1)
		idx += 1
	if added:
		lines.surface_end()
	_ribbon.mesh = lines
	for g in range(4):
		var p := Vector3(float(4 + g * 3) * CELL_UNITS, float(active_floor) * FLOOR_RISE + 0.45, float(3 + active_floor) * CELL_UNITS)
		_add_beacon(p, GO_COLORS[g])


func _add_node(cell: Vector2i, col: Color, number: int) -> void:
	var m := MeshInstance3D.new()
	m.mesh = _sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.position = Vector3(float(cell.x) * CELL_UNITS + 0.75, float(active_floor) * FLOOR_RISE + 0.18, float(cell.y) * CELL_UNITS + 0.75)
	m.name = "WP%d" % number
	_nodes.add_child(m)


func _add_beacon(pos: Vector3, col: Color) -> void:
	var m := MeshInstance3D.new()
	m.mesh = _box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.position = pos
	m.scale = Vector3(0.5, 0.9, 0.5)
	_beacons.add_child(m)
