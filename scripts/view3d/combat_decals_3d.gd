# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name CombatDecals3D
extends Node3D


const MAX_DECALS: int = 128
var _mesh: MultiMeshInstance3D = null
var _next: int = 0


func _ready() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = BoxMesh.new()
	mm.instance_count = MAX_DECALS
	_mesh = MultiMeshInstance3D.new()
	_mesh.name = "ScorchAndBrass"
	_mesh.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.05, 0.04, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mesh.material_override = mat
	add_child(_mesh)
	var hidden := Transform3D().scaled(Vector3.ZERO)
	for i in range(MAX_DECALS):
		mm.set_instance_transform(i, hidden)


func stamp(pos: Vector3, scale: float = 0.6) -> void:
	if _mesh == null:
		return
	var idx: int = _next % MAX_DECALS
	var t := Transform3D().translated(pos + Vector3(0.0, 0.04, 0.0)).scaled(Vector3(scale, 0.02, scale))
	_mesh.multimesh.set_instance_transform(idx, t)
	_next += 1


func stamp_breach(pos: Vector3) -> void:
	stamp(pos, 1.1)
	stamp(pos + Vector3(0.4, 0.0, 0.3), 0.5)


func count_stamps() -> int:
	return mini(_next, MAX_DECALS)
