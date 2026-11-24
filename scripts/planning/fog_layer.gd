# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name FogLayer
extends Node2D


var live_vp: SubViewport = null
var memory_vp: SubViewport = null
var _map: GreyboxMap = null
var _door_open: Dictionary = {}
var _wall_segments: Array = []
var _live_origins: Array[Vector2] = []
var _polygons: Dictionary = {}
var _live_shapes: Array[Polygon2D] = []
var _memory_shapes: Array[Polygon2D] = []
var _pending_memory := 0


func setup(m: GreyboxMap) -> void:
	var extent := Vector2i(m.width_cells, m.height_cells) * SimConstants.GRID_CELL_SIZE_PX
	live_vp = _make_viewport(extent)
	memory_vp = _make_viewport(extent)
	memory_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	RenderingServer.frame_post_draw.connect(_retire_memory_shapes)

	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/planning/fog_mask.gdshader")
	mat.set_shader_parameter("live_tex", live_vp.get_texture())
	mat.set_shader_parameter("memory_tex", memory_vp.get_texture())
	var comp := ColorRect.new()
	comp.size = Vector2(extent)
	comp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	comp.material = mat
	add_child(comp)


func _make_viewport(extent: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = extent
	vp.msaa_2d = Viewport.MSAA_DISABLED
	vp.disable_3d = true
	vp.transparent_bg = true
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	return vp


func update_visibility(world: SimWorld, local_faction_id: int) -> void:
	var geometry_changed := _map != world.map or _door_open != world.map.door_open
	if geometry_changed:
		_map = world.map
		_door_open = _map.door_open.duplicate()
		_wall_segments = _map.get_wall_segments()
		_polygons.clear()

	var origins: Array[Vector2] = []
	for operative in world.operatives:
		if operative.faction_id == local_faction_id and operative.is_alive():
			origins.append(operative.pos)
	for drone in world.drones:
		if not drone.destroyed:
			origins.append(drone.pos)
	if not geometry_changed and origins == _live_origins:
		return

	var next_polygons: Dictionary = {}
	var live_count := 0
	for origin in origins:
		if next_polygons.has(origin):
			continue
		var poly: PackedVector2Array
		if _polygons.has(origin):
			poly = _polygons[origin]
		else:
			poly = Visibility.compute_polygon(origin, _wall_segments, SimConstants.LOS_VERTEX_EPSILON_RAD)
			if poly.size() >= 3:
				_write_shape(memory_vp, _memory_shapes, _pending_memory, poly)
				_pending_memory += 1
				memory_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		next_polygons[origin] = poly
		if poly.size() >= 3:
			_write_shape(live_vp, _live_shapes, live_count, poly)
			live_count += 1
	for i in range(live_count, _live_shapes.size()):
		_live_shapes[i].hide()
	_polygons = next_polygons
	_live_origins = origins
	live_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _write_shape(vp: SubViewport, pool: Array[Polygon2D], index: int, poly: PackedVector2Array) -> void:
	if index == pool.size():
		var created := Polygon2D.new()
		created.color = Color.WHITE
		created.scale = Vector2.ONE * float(SimConstants.GRID_CELL_SIZE_PX)
		pool.append(created)
		vp.add_child(created)
	var shape := pool[index]
	if shape.polygon != poly:
		shape.polygon = poly
	shape.show()


func _retire_memory_shapes() -> void:
	for i in range(_pending_memory):
		_memory_shapes[i].hide()
	_pending_memory = 0


func reset_fog() -> void:
	_map = null
	_door_open.clear()
	_wall_segments.clear()
	_live_origins.clear()
	_polygons.clear()
	_retire_memory_shapes()
	for shape in _live_shapes:
		shape.hide()
	live_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	memory_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	memory_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
