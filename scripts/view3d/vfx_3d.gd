# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name Vfx3D
extends Node3D


const LIGHT_POOL: int = 4
const TRACER_POOL: int = 8
const RING_POOL: int = 4
const RUBBLE_POOL: int = 24


var _lights: Array[OmniLight3D] = []
var _tracers: Array[MeshInstance3D] = []
var _rings: Array[MeshInstance3D] = []
var _life: Array[float] = []
var _tracer_life: Array[float] = []
var _ring_life: Array[float] = []
var _light_mesh: BoxMesh = null
var _ring_mesh: CylinderMesh = null
var _rubble: Array[MeshInstance3D] = []
var _rubble_vel: Array[Vector3] = []
var _rubble_life: Array[float] = []


func _ready() -> void:
	for i in range(LIGHT_POOL):
		var l := OmniLight3D.new()
		l.name = "FlashLight%d" % i
		l.light_energy = 0.0
		l.omni_range = 7.0
		add_child(l)
		_lights.append(l)
		_life.append(0.0)
	for i in range(TRACER_POOL):
		var m := MeshInstance3D.new()
		m.name = "Tracer%d" % i
		_light_mesh = BoxMesh.new()
		m.mesh = _light_mesh
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.8, 0.25)
		m.material_override = mat
		m.visible = false
		add_child(m)
		_tracers.append(m)
		_tracer_life.append(0.0)
	for i in range(RING_POOL):
		var r := MeshInstance3D.new()
		r.name = "ShockRing%d" % i
		_ring_mesh = CylinderMesh.new()
		_ring_mesh.height = 0.04
		r.mesh = _ring_mesh
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.5, 0.12, 0.7)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		r.material_override = mat
		r.visible = false
		add_child(r)
		_rings.append(r)
		_ring_life.append(0.0)
	var cube := BoxMesh.new()
	for i in range(RUBBLE_POOL):
		var r := MeshInstance3D.new()
		r.name = "Rubble%d" % i
		r.mesh = cube
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.42, 0.45, 0.50) if i % 2 == 0 else Color(0.58, 0.48, 0.36)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		r.material_override = mat
		r.visible = false
		add_child(r)
		_rubble.append(r)
		_rubble_vel.append(Vector3.ZERO)
		_rubble_life.append(0.0)


func muzzle(pos: Vector3, col: Color = Color(1.0, 0.72, 0.25)) -> void:
	_spawn_light(pos, col, 6.0)


func flashbang(pos: Vector3) -> void:
	_spawn_light(pos + Vector3.UP * 1.0, Color(1, 1, 1), 12.0)
	_spawn_ring(pos, 1.6)


func breach(pos: Vector3) -> void:
	_spawn_light(pos + Vector3.UP * 0.6, Color(1.0, 0.45, 0.1), 14.0)
	_spawn_ring(pos, 2.4)
	spawn_breach_rubble(pos)


func spawn_breach_rubble(pos: Vector3) -> void:
	var n := 0
	for i in range(RUBBLE_POOL):
		if _rubble_life[i] > 0.0:
			continue
		var a := float(i) * 2.39996
		var speed := 1.6 + float(i % 5) * 0.45
		_rubble_vel[i] = Vector3(cos(a) * speed, 2.4 + float(i % 3) * 0.6, sin(a) * speed)
		_rubble[i].position = pos + Vector3(0.0, 0.4, 0.0)
		_rubble[i].rotation = Vector3(float(i) * 0.31, float(i) * 0.77, float(i) * 0.19)
		_rubble[i].scale = Vector3.ONE * (0.11 + float(i % 4) * 0.04)
		_rubble[i].visible = true
		_rubble_life[i] = 4.0
		n += 1
		if n >= 16:
			break


func tracer(from: Vector3, to: Vector3) -> void:
	var idx := _oldest_tracer()
	var m := _tracers[idx]
	var mid := (from + to) * 0.5
	m.position = mid
	m.scale = Vector3(0.05, 0.05, from.distance_to(to))
	m.look_at(to, Vector3.UP)
	m.visible = true
	_tracer_life[idx] = 0.08


func _spawn_light(pos: Vector3, col: Color, energy: float) -> void:
	var idx := _oldest_light()
	var l := _lights[idx]
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	_life[idx] = 0.16


func _spawn_ring(pos: Vector3, scale: float) -> void:
	var idx := _oldest_ring()
	var r := _rings[idx]
	r.position = pos + Vector3.UP * 0.1
	r.scale = Vector3.ONE * scale
	r.visible = true
	_ring_life[idx] = 0.45


func _oldest_light() -> int:
	var best := 0
	for i in range(_life.size()):
		if _life[i] < _life[best]:
			best = i
	return best


func _oldest_tracer() -> int:
	var best := 0
	for i in range(_tracer_life.size()):
		if _tracer_life[i] < _tracer_life[best]:
			best = i
	return best


func _oldest_ring() -> int:
	var best := 0
	for i in range(_ring_life.size()):
		if _ring_life[i] < _ring_life[best]:
			best = i
	return best


func _process(delta: float) -> void:
	for i in range(_life.size()):
		if _life[i] <= 0.0:
			continue
		_life[i] -= delta
		_lights[i].light_energy = maxf(0.0, _life[i] * 60.0)
	for i in range(_tracer_life.size()):
		if _tracer_life[i] <= 0.0:
			continue
		_tracer_life[i] -= delta
		if _tracer_life[i] <= 0.0:
			_tracers[i].visible = false
	for i in range(_ring_life.size()):
		if _ring_life[i] <= 0.0:
			continue
		_ring_life[i] -= delta
		_rings[i].scale *= 1.0 + delta * 1.8
		if _ring_life[i] <= 0.0:
			_rings[i].visible = false
	for i in range(RUBBLE_POOL):
		if _rubble_life[i] <= 0.0:
			continue
		_rubble_life[i] -= delta
		_rubble_vel[i].y -= 7.8 * delta
		_rubble[i].position += _rubble_vel[i] * delta
		_rubble[i].rotation += _rubble_vel[i] * delta * 0.35
		if _rubble[i].position.y < 0.1:
			_rubble[i].position.y = 0.1
			_rubble_vel[i].y = absf(_rubble_vel[i].y) * 0.34
			_rubble_vel[i].x *= 0.7
			_rubble_vel[i].z *= 0.7
		if _rubble_life[i] <= 0.0:
			_rubble[i].visible = false
