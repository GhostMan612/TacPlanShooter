# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name Vehicle3DLayer
extends Node3D


const CELL_UNITS: float = 1.5
const FLOOR_RISE: float = 3.2
var _nodes: Dictionary = {}
var _box: BoxMesh = null


func _ready() -> void:
	_box = BoxMesh.new()


func sync(w: SimWorld, floor: int) -> void:
	if w == null:
		return
	var seen := {}
	for v in w.vehicles:
		if v == null:
			continue
		seen[v.id] = true
		if not _nodes.has(v.id):
			_spawn(v)
		var n: Node3D = _nodes[v.id]
		n.position = Vector3(v.pos.x * CELL_UNITS, float(floor) * FLOOR_RISE + 0.65, v.pos.y * CELL_UNITS)
		var led := n.get_node_or_null("Lightbar") as OmniLight3D
		if led != null:
			led.light_color = Color(1.0, 0.15, 0.1) if (Time.get_ticks_msec() / 400) % 2 == 0 else Color(0.15, 0.3, 1.0)
	for id in _nodes.keys():
		if not seen.has(id):
			(_nodes[id] as Node3D).visible = false


func _spawn(v: SimVehicle) -> void:
	var root := Node3D.new()
	root.name = "Vehicle%d" % v.id
	var body := MeshInstance3D.new()
	body.mesh = _box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.26, 0.31) if v.type == int(SimVehicle.Type.APC) else Color(0.32, 0.35, 0.39)
	mat.metallic = 0.5
	body.material_override = mat
	body.scale = Vector3(3.4, 1.6, 1.8) if v.type == int(SimVehicle.Type.APC) else Vector3(4.2, 1.7, 1.7)
	root.add_child(body)
	if v.type == int(SimVehicle.Type.APC):
		var led := OmniLight3D.new()
		led.name = "Lightbar"
		led.light_color = Color(1.0, 0.15, 0.1)
		led.omni_range = 6.0
		led.light_energy = 3.0
		led.position = Vector3(0.0, 1.1, 0.0)
		root.add_child(led)
	add_child(root)
	_nodes[v.id] = root
