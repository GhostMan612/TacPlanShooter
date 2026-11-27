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
var route_overlay: Route3DOverlay = null
var fog_overlay: Fog3DOverlay = null
var vfx: Vfx3D = null
var drone_layer: Drone3DLayer = null
var vehicle_layer: Vehicle3DLayer = null
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
var _dir_textures: Dictionary = {}


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
	route_overlay = Route3DOverlay.new()
	route_overlay.name = "RouteOverlay3D"
	add_child(route_overlay)
	fog_overlay = Fog3DOverlay.new()
	fog_overlay.name = "FogOverlay3D"
	add_child(fog_overlay)
	vfx = Vfx3D.new()
	vfx.name = "Vfx3D"
	add_child(vfx)
	drone_layer = Drone3DLayer.new()
	drone_layer.name = "Drones3D"
	add_child(drone_layer)
	vehicle_layer = Vehicle3DLayer.new()
	vehicle_layer.name = "Vehicles3D"
	add_child(vehicle_layer)
	var bus := get_node_or_null("/root/EventBus")
	if bus != null:
		if not bus.breach_detonated.is_connected(_on_breach_3d):
			bus.breach_detonated.connect(_on_breach_3d)
		if not bus.operative_damaged.is_connected(_on_op_damaged_3d):
			bus.operative_damaged.connect(_on_op_damaged_3d)
	camera = TacticalCamera3D.new()
	camera.name = "TacticalCamera3D"
	add_child(camera)
	var sun := DirectionalLight3D.new()
	sun.name = "TacticalSun"
	sun.light_energy = 0.8
	sun.rotation_degrees = Vector3(-52.0, 38.0, 0.0)
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.08, 0.12)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.42, 0.52, 0.66)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)
	_box_mesh = BoxMesh.new()
	_floor_material = StandardMaterial3D.new()
	_floor_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_floor_material.albedo_color = Color(0.62, 0.70, 0.82)
	_floor_material.roughness = 0.9
	_floor_material.uv1_triplanar = true
	var floor_tex := ResourceLoader.load("res://assets/textures/concrete_seamless_256.png", "Texture2D") as Texture2D
	if floor_tex != null:
		_floor_material.albedo_texture = floor_tex
	var floor_normal := ResourceLoader.load("res://assets/textures/spacegrunts_25d_tileset_n.png", "Texture2D") as Texture2D
	if floor_normal != null:
		_floor_material.normal_texture = floor_normal
	var shader_path := "res://scripts/view3d/wall_cutaway.gdshader"
	if ResourceLoader.exists(shader_path):
		_wall_material = ShaderMaterial.new()
		_wall_material.shader = ResourceLoader.load(shader_path) as Shader
		camera.cutaway_material = _wall_material
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
	var dir_paths := {
		&"pointman": "res://assets/sprites/8dir/op_pointman_8dir.png",
		&"breacher": "res://assets/sprites/8dir/op_breacher_8dir.png",
		&"shield": "res://assets/sprites/8dir/op_shield_8dir.png",
		&"tech": "res://assets/sprites/8dir/op_tech_8dir.png",
		&"hostile": "res://assets/sprites/8dir/hostile_sentry_8dir.png",
		&"hostage": "res://assets/sprites/8dir/hostage_8dir.png",
	}
	for key in dir_paths.keys():
		var path: String = dir_paths[key]
		if ResourceLoader.exists(path):
			var tex := ResourceLoader.load(path, "Texture2D") as Texture2D
			if tex != null:
				_dir_textures[key] = tex
	rebuild()
	camera.focus(cell_to_world(Vector2i(map.width_cells / 2, map.height_cells / 2), floor))
	camera.on_resize(viewport)
	_on_resize(viewport)


func is_active() -> bool:
	return _active


func set_fog(f: FogLayer) -> void:
	if f != null and fog_overlay != null and map != null:
		fog_overlay.configure(f, map, active_floor)


func update_routes(src: Dictionary) -> void:
	if route_overlay != null:
		route_overlay.set_routes(src, active_floor)


static func world_pos_to_3d(p: Vector2, floor: int) -> Vector3:
	return Vector3(p.x * CELL_UNITS, float(floor) * FLOOR_RISE + 0.6, p.y * CELL_UNITS)


func _on_breach_3d(p: Vector2) -> void:
	if vfx != null:
		vfx.breach(world_pos_to_3d(p, active_floor))
	if camera != null:
		camera.shake(0.45)


func _on_op_damaged_3d(_id: int, _hp: int) -> void:
	if camera != null:
		camera.shake(0.18)


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
		camera.enter_tap_in_follow()


func release_tap_in() -> void:
	if camera != null:
		camera.release_tap_in()


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
		var props := _build_props(fm, f)
		_floor_root.add_child(plate)
		_floor_root.add_child(walls)
		_floor_root.add_child(props)
		var ao := _build_ao(fm, f)
		_floor_root.add_child(ao)
		_build_doors(fm, f)
		_floor_meshes[f] = {"floor": plate, "walls": walls, "ao": ao}
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


func _build_props(fm: GreyboxMap, floor: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.mesh = _box_mesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var spots: Array[Vector2i] = []
	for y in range(1, fm.height_cells - 1):
		for x in range(1, fm.width_cells - 1):
			var c := Vector2i(x, y)
			var h := (x * 73856093) ^ (y * 19349663)
			if (h & 7) == 0 and not fm.is_solid(c):
				spots.append(c)
	mm.instance_count = spots.size()
	for i in range(spots.size()):
		var c: Vector2i = spots[i]
		var p: Vector3 = cell_to_world(c, floor) + Vector3(0.0, 0.35, 0.0)
		mm.set_instance_transform(i, Transform3D().translated(p).scaled(Vector3(0.55, 0.7, 0.55)))
	var inst := MultiMeshInstance3D.new()
	inst.name = "RoomProps%d" % floor
	inst.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.33, 0.40)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	inst.material_override = mat
	return inst


func _build_ao(fm: GreyboxMap, floor: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.mesh = _box_mesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var spots: Array[Vector2i] = []
	for y in range(fm.height_cells):
		for x in range(fm.width_cells):
			var c := Vector2i(x, y)
			if fm.is_solid(c):
				continue
			if fm.solid_cells.has(c + Vector2i(0, -1)) or fm.solid_cells.has(c + Vector2i(-1, 0)) or fm.solid_cells.has(c + Vector2i(1, 0)):
				spots.append(c)
	mm.instance_count = spots.size()
	for i in range(spots.size()):
		var c: Vector2i = spots[i]
		var p: Vector3 = cell_to_world(c, floor) + Vector3(0.0, 0.02, 0.0)
		mm.set_instance_transform(i, Transform3D().translated(p).scaled(Vector3(CELL_UNITS, 0.02, CELL_UNITS)))
	var inst := MultiMeshInstance3D.new()
	inst.name = "WallAO%d" % floor
	inst.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.04, 0.07, 0.42)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inst.material_override = mat
	return inst


func _build_doors(fm: GreyboxMap, floor: int) -> void:
	for key in fm.door_cells.keys():
		var c := Vector2i(key)
		var box := MeshInstance3D.new()
		box.name = "Door3D_%d_%d_f%d" % [c.x, c.y, floor]
		var mesh := BoxMesh.new()
		box.mesh = mesh
		var mat := StandardMaterial3D.new()
		var state := fm.door_state(c)
		mat.albedo_color = Color(0.24, 0.30, 0.38) if state == &"OPEN" else Color(0.55, 0.20, 0.12)
		mat.emission_enabled = true
		mat.emission = mat.albedo_color * 0.3
		if state == &"BREACHED_DESTROYED":
			mat.albedo_color = Color(0.16, 0.18, 0.21)
			mat.emission = Color(0.95, 0.45, 0.10)
			mat.emission_energy_multiplier = 0.6
		box.material_override = mat
		box.position = cell_to_world(c, floor) + Vector3(0.0, 1.1, 0.0)
		box.scale = Vector3(0.45, 0.55, 0.25) if state == &"BREACHED_DESTROYED" else Vector3(1.35, 2.2, 0.25)
		_floor_root.add_child(box)


func _apply_floor_visibility() -> void:
	for f in _floor_meshes.keys():
		var entry: Dictionary = _floor_meshes[f]
		var shown: bool = int(f) == active_floor
		(entry.get("floor") as Node3D).visible = shown
		(entry.get("walls") as Node3D).visible = shown
		if entry.has("ao"):
			(entry.get("ao") as Node3D).visible = shown


func _signature() -> String:
	if world == null:
		return ""
	var out := PackedStringArray()
	var doors: Dictionary = world.door_system.doors
	for key in doors.keys():
		out.append("%s:%d" % [str(key), int(world.door_system.state(key))])
	out.sort()
	return "|".join(out)


func _emit_breach_rubble() -> void:
	if world == null or vfx == null:
		return
	for key in world.door_system.doors.keys():
		if world.door_system.state(key) == int(DoorSystem.State.BREACHED_DESTROYED):
			var cell := Vector2i(key)
			vfx.spawn_breach_rubble(cell_to_world(cell, active_floor))
			return


func sync_from_world(w: SimWorld, floor: int, local_faction: int) -> void:
	if w == null:
		return
	world = w
	active_floor = floor
	var sig := _signature()
	if sig != _door_signature:
		_emit_breach_rubble()
		rebuild()
	else:
		_apply_floor_visibility()
	var seen := {}
	for o in w.operatives:
		_sync_actor(o, seen, local_faction)
	if drone_layer != null:
		drone_layer.sync(w, active_floor)
	if vehicle_layer != null:
		vehicle_layer.sync(w, active_floor)
	if not w.operatives.is_empty() and _wall_material != null:
		var lead: SimOperative = w.operatives[0]
		_wall_material.set_shader_parameter("focus_pos", actor_to_world(lead))
	for id in w.enemy_actors.keys():
		var enemy: Variant = w.enemy_actors[id]
		if enemy is SimOperative:
			_sync_actor(enemy as SimOperative, seen, local_faction)
	for id in _actors.keys():
		if not seen.has(id):
			var stale := _actors[id] as Node3D
			if stale != null:
				stale.visible = false


func _sync_actor(o: SimOperative, seen: Dictionary, local_faction: int) -> void:
	if o == null:
		return
	if not _actors.has(o.id):
		var is_friendly: bool = o.faction_id == local_faction
		var tint := Color(0.82, 0.92, 1.0) if is_friendly else Color(1.0, 0.82, 0.78)
		var rig := Unit8DirSpriteRig.new()
		rig.name = "Actor%d" % o.id
		if rig.configure(is_friendly, tint):
			_actor_root.add_child(rig)
			_actors[o.id] = rig
		else:
			rig.free()
			var sprite := Sprite3D.new()
			sprite.name = "Actor%d" % o.id
			sprite.billboard = 2
			sprite.shaded = false
			sprite.centered = true
			sprite.pixel_size = 0.035
			sprite.hframes = 8
			sprite.vframes = 1
			var key: StringName = &"pointman" if is_friendly else &"hostile"
			if _dir_textures.has(key):
				sprite.texture = _dir_textures[key]
			elif not _actor_textures.is_empty():
				var idx: int = o.id if is_friendly else _actor_textures.size() - 1
				sprite.texture = _actor_textures[posmod(idx, _actor_textures.size())]
			_actor_root.add_child(sprite)
			_actors[o.id] = sprite
	var node := _actors[o.id] as Node3D
	if node == null:
		return
	seen[o.id] = true
	node.visible = o.floor_idx == active_floor and o.is_alive()
	if node is Unit8DirSpriteRig:
		node.update_from_sim(actor_to_world(o), deg_to_rad(o.facing_deg), camera)
	elif node is Sprite3D:
		var s := node as Sprite3D
		s.global_position = actor_to_world(o)
		var rel_deg := wrapf(o.facing_deg - (camera.yaw_deg if camera != null else 0.0) + 22.5, 0.0, 360.0)
		s.frame = int(floor(rel_deg / 45.0)) % 8
