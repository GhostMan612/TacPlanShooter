# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name FogLayer
extends Node2D


var map: GreyboxMap = null
var live_vp: SubViewport = null
var memory_vp: SubViewport = null
var _comp: ColorRect = null
var _memory_shapes: Dictionary = {}


func setup(m: GreyboxMap) -> void:
	map = m
	var w := int(float(map.width_cells) * float(SimConstants.GRID_CELL_SIZE_PX))
	var h := int(float(map.height_cells) * float(SimConstants.GRID_CELL_SIZE_PX))
	live_vp = SubViewport.new()
	live_vp.size = Vector2i(w, h)
	live_vp.msaa_2d = Viewport.MSAA_DISABLED
	live_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	live_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(live_vp)
	memory_vp = SubViewport.new()
	memory_vp.size = Vector2i(w, h)
	memory_vp.msaa_2d = Viewport.MSAA_DISABLED
	memory_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	memory_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(memory_vp)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/planning/fog_mask.gdshader")
	_comp = ColorRect.new()
	_comp.size = Vector2(w, h)
	_comp.material = mat
	_comp.material.set_shader_parameter("live_tex", live_vp.get_texture())
	_comp.material.set_shader_parameter("memory_tex", memory_vp.get_texture())
	add_child(_comp)


func rebuild(visible_polys: Array) -> void:
	var kids := live_vp.get_children()
	for k in kids:
		k.free()
	for poly in visible_polys:
		var shape := Polygon2D.new()
		shape.set_polygon(poly)
		shape.color = Color.WHITE
		live_vp.add_child(shape)
	live_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func mark_memory(cell: Vector2i) -> void:
	if _memory_shapes.has(cell):
		return
	var shape := Polygon2D.new()
	shape.set_polygon(_cell_rect_points(cell))
	shape.color = Color.WHITE
	memory_vp.add_child(shape)
	memory_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_memory_shapes[cell] = shape


func mark_visible(poly: PackedVector2Array) -> void:
	if poly.size() < 3:
		return
	for c in _map_cells():
		if Geometry2D.is_point_in_polygon(GridUtil.cell_center_px(c), poly):
			mark_memory(c)


func _map_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(map.height_cells):
		for x in range(map.width_cells):
			out.append(Vector2i(x, y))
	return out


func reset_fog() -> void:
	var kids := memory_vp.get_children()
	for k in kids:
		k.free()
	_memory_shapes.clear()
	memory_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE


func poly_contains(p: Vector2, poly: PackedVector2Array) -> bool:
	return Geometry2D.is_point_in_polygon(p, poly)


func _cell_rect_points(c: Vector2i) -> PackedVector2Array:
	var rect := GridUtil.cell_rect_px(c)
	var e := Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y)
	var p := PackedVector2Array()
	p.append(rect.position)
	p.append(Vector2(e.x, rect.position.y))
	p.append(e)
	p.append(Vector2(rect.position.x, e.y))
	return p
