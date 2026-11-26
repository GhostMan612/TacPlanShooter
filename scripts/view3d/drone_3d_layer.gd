# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name Drone3DLayer
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
	for d in w.drones:
		var drone_floor := int(d.get("floor_idx"))
		if drone_floor != floor:
			continue
		seen[d.id] = true
		if not _nodes.has(d.id):
			_spawn(d)
		var n: Node3D = _nodes[d.id]
		var bob := sin(Time.get_ticks_msec() * 0.004 + float(d.id)) * 0.12
		var base := Vector3(d.pos.x * CELL_UNITS, float(floor) * FLOOR_RISE, d.pos.y * CELL_UNITS)
		if d.kind == int(SimDrone.Class.MICRO_UAV):
			n.position = base + Vector3(0.0, 2.0 + bob, 0.0)
		else:
			n.position = base + Vector3(0.0, 0.25, 0.0)
		var body := n.get_node_or_null("Body") as MeshInstance3D
		if body != null:
			body.visible = not d.destroyed
		var light := n.get_node_or_null("Optic") as OmniLight3D
		if light != null:
			light.visible = not d.destroyed and d.battery > 0
			light.light_energy = clampf(float(d.signal_strength) / 100.0, 0.1, 1.0) * 2.0
	for id in _nodes.keys():
		if not seen.has(id):
			(_nodes[id] as Node3D).visible = false


func _spawn(d: SimDrone) -> void:
	var root := Node3D.new()
	root.name = "Drone%d" % d.id
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.35, 0.45) if d.kind == int(SimDrone.Class.MICRO_UAV) else Color(0.18, 0.24, 0.30)
	mat.metallic = 0.4
	body.material_override = mat
	body.scale = Vector3(0.9, 0.22, 0.9) if d.kind == int(SimDrone.Class.MICRO_UAV) else Vector3(1.0, 0.4, 1.2)
	root.add_child(body)
	var optic := OmniLight3D.new()
	optic.name = "Optic"
	optic.light_color = Color(0.2, 0.95, 1.0)
	optic.omni_range = 5.0
	optic.light_energy = 2.0
	root.add_child(optic)
	add_child(root)
	_nodes[d.id] = root
