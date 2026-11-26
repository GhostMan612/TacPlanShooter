# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name WorldView3D
extends Node3D

const CELL_UNITS: float = 1.5
const FLOOR_RISE: float = 3.2
const WALL_HEIGHT: float = 2.6
const ACTOR_LIFT: float = 0.9

var world: SimWorld = null
var map: GreyboxMap = null
var active_floor: int = 0
var camera: TacticalCamera3D = null
var _floor_root: Node3D = null
var _actor_root: Node3D = null
var _floor_meshes: Dictionary = {}
var _actors: Dictionary = {}
var _door_signature: String = ""
var _active: bool = false
var _box_mesh: BoxMesh = null
var _floor_material: StandardMaterial3D = null
var _wall_material: ShaderMaterial = null
var _actor_textures: Array[Texture2D] = []


func setup(w: SimWorld, m: GreyboxMap, floor: int, viewport: Vector2) -> void:
	world = w
	map = m
	active_floor = floor
	_floor_root = Node3D.new()
	_floor_root.name = "FloorGeometry"
	add_child(_floor_root)
	_actor_root = Node3D.new()
	_actor_root.name = "Actors"
	add_child(_actor_root)
	camera = TacticalCamera3D.new()
	camera.name = "TacticalCamera3D"
	add_child(camera)
	_box_mesh = BoxMesh.new()
	_floor_material = StandardMaterial3D.new()
	_floor_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var shader_path := "res://scripts/view3d/wall_cutaway.gdshader"
	if ResourceLoader.exists(shader_path):
		_wall_material = ShaderMaterial.new()
		_wall_material.shader = ResourceLoader.load(shader_path) as Shader
	var paths := [
		"res://assets/sprites/op_breacher.png",
		"res://assets/sprites/op_pointman.png",
		"res://assets/sprites/op_tech.png",
		"res://assets/sprites/op_heavy.png",
		"res://assets/sprites/op_hostile_sentry.png",
	]
	for path in paths:
		if ResourceLoader.exists(path):
			var tex := ResourceLoader.load(path) as Texture2D
			if tex != null:
				_actor_textures.append(tex)
	rebuild()
	camera.focus(cell_to_world(Vector2i(map.width_cells / 2, map.height_cells / 2), floor))
	camera.on_resize(viewport)
	_on_resize(viewport)


func is_active() -> bool:
	return _active


func set_active(value: bool) -> void:
	_active = value
	visible = value
	if camera != null:
		camera.set_active(value)
	if value:
		sync_from_world(world, active_floor, 0)


func on_resize(size: Vector2) -> void:
	if camera != null:
		camera.on_resize(size)
	_on_resize(size)


func _on_resize(_size: Vector2) -> void:
	pass


static func cell_to_world(cell: Vector2i, floor: int) -> Vector3:
	return Vector3(float(cell.x) * CELL_UNITS, float(floor) * FLOOR_RISE, float(cell.y) * CELL_UNITS)


static func actor_to_world(o: SimOperative) -> Vector3:
	return Vector3(o.pos.x * CELL_UNITS, float(o.floor_idx) * FLOOR_RISE + ACTOR_LIFT, o.pos.y * CELL_UNITS)


func set_active_floor(f: int) -> void:
	active_floor = f
	_apply_floor_visibility()
	if camera != null:
		camera.focus(cell_to_world(Vector2i(map.width_cells / 2, map.height_cells / 2), f))


func snap_yaw(direction: int) -> void:
	if camera != null:
		camera.snap_yaw(direction)


func twist_by(delta_deg: float) -> void:
	if camera != null:
		camera.twist_by(delta_deg)


func snap_nearest() -> void:
	if camera != null:
		camera.snap_nearest()


func cycle_pitch() -> void:
	if camera != null:
		camera.cycle_pitch()


func follow_actor(o: SimOperative) -> void:
	if camera != null and o != null:
		camera.focus(actor_to_world(o))


func rebuild() -> void:
	if world == null or map == null or _floor_root == null:
		return
	for child in _floor_root.get_children():
		child.free()
	_floor_meshes.clear()
	var count: int = maxi(1, map.floor_count)
	for f in range(count):
		var fm: GreyboxMap = world.map_on_floor(f)
		if fm == null:
			fm = map.slice_map(f)
		if fm == null:
			continue
		var plate := _build_floor(fm, f)
		var walls := _build_walls(fm, f)
		_floor_root.add_child(plate)
		_floor_root.add_child(walls)
		_floor_meshes[f] = {"floor": plate, "walls": walls}
	_door_signature = _signature()
	_apply_floor_visibility()


func _build_floor(fm: GreyboxMap, floor: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.mesh = _box_mesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var cells: Array[Vector2i] = []
	for y in range(fm.height_cells):
		for x in range(fm.width_cells):
			cells.append(Vector2i(x, y))
	mm.instance_count = cells.size()
	for i in range(cells.size()):
		var c: Vector2i = cells[i]
		var p: Vector3 = cell_to_world(c, floor) + Vector3(0.0, -0.06, 0.0)
		mm.set_instance_transform(i, Transform3D().translated(p).scaled(Vector3(CELL_UNITS, 0.1, CELL_UNITS)))
		var shade: float = 0.0 if ((c.x + c.y) & 1) == 0 else 0.35
		mm.set_instance_custom_data(i, Color(shade, 0.0, 0.0, 1.0))
	var inst := MultiMeshInstance3D.new()
	inst.name = "FloorPlates%d" % floor
	inst.multimesh = mm
	if _floor_material != null:
		inst.material_override = _floor_material
	return inst


func _build_walls(fm: GreyboxMap, floor: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.mesh = _box_mesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var cells: Array[Vector2i] = []
	for key in fm.solid_cells.keys():
		cells.append(Vector2i(key))
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	mm.instance_count = cells.size()
	for i in range(cells.size()):
		var c: Vector2i = cells[i]
		var base: Vector3 = cell_to_world(c, floor)
		var p := Vector3(base.x, base.y + WALL_HEIGHT * 0.5, base.z)
		mm.set_instance_transform(i, Transform3D().translated(p).scaled(Vector3(CELL_UNITS, WALL_HEIGHT, CELL_UNITS)))
		mm.set_instance_custom_data(i, Color(1.0, 0.0, 0.0, 1.0))
	var inst := MultiMeshInstance3D.new()
	inst.name = "Walls%d" % floor
	inst.multimesh = mm
	if _wall_material != null:
		inst.material_override = _wall_material
	return inst


func _apply_floor_visibility() -> void:
	for f in _floor_meshes.keys():
		var entry: Dictionary = _floor_meshes[f]
		var shown: bool = int(f) == active_floor
		(entry.get("floor") as Node3D).visible = shown
		(entry.get("walls") as Node3D).visible = shown


func _signature() -> String:
	if world == null:
		return ""
	var out := PackedStringArray()
	var doors: Dictionary = world.door_system.doors
	for key in doors.keys():
		out.append("%s:%d" % [str(key), int(world.door_system.state(key))])
	out.sort()
	return "|".join(out)


func sync_from_world(w: SimWorld, floor: int, local_faction: int) -> void:
	if w == null:
		return
	world = w
	active_floor = floor
	if _signature() != _door_signature:
		rebuild()
	else:
		_apply_floor_visibility()
	var seen := {}
	for o in w.operatives:
		_sync_actor(o, seen, local_faction)
	if not w.operatives.is_empty() and _wall_material != null:
		var lead: SimOperative = w.operatives[0]
		_wall_material.set_shader_parameter("focus_pos", actor_to_world(lead))
	for id in w.enemy_actors.keys():
		var enemy: Variant = w.enemy_actors[id]
		if enemy is SimOperative:
			_sync_actor(enemy as SimOperative, seen, local_faction)
	for id in _actors.keys():
		if not seen.has(id):
			(_actors[id] as Sprite3D).visible = false


func _sync_actor(o: SimOperative, seen: Dictionary, local_faction: int) -> void:
	if o == null:
		return
	if not _actors.has(o.id):
		var sprite := Sprite3D.new()
		sprite.name = "Actor%d" % o.id
		sprite.billboard = 2
		sprite.shaded = false
		sprite.centered = true
		sprite.pixel_size = 0.022
		if not _actor_textures.is_empty():
			var idx: int = o.id if o.faction_id == local_faction else _actor_textures.size() - 1
			sprite.texture = _actor_textures[posmod(idx, _actor_textures.size())]
		_actor_root.add_child(sprite)
		_actors[o.id] = sprite
	var s := _actors[o.id] as Sprite3D
	seen[o.id] = true
	s.global_position = actor_to_world(o)
	s.visible = o.floor_idx == active_floor and o.is_alive()
	var sector: int = posmod(int(roundf(fposmod(o.facing_deg, 360.0) / 45.0)), 8)
	s.flip_h = sector >= 4
