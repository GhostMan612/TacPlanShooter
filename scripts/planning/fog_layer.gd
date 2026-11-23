# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name FogLayer
extends Node2D


const FOG_COLOR := Color(0.10, 0.11, 0.14, 0.62)
const MEMORY_COLOR := Color(0.55, 0.45, 0.24, 0.50)


var map: GreyboxMap = null
var fog_cells: Array[Vector2i] = []
var memory_cells: Array[Vector2i] = []


func setup(m: GreyboxMap) -> void:
	map = m


func visible_cells(visible_polys: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if map == null:
		return out
	for c in _map_cells():
		if _in_any_poly(GridUtil.cell_center_px(c), visible_polys):
			out.append(c)
	return out


func rebuild(visible_polys: Array, visited: Dictionary) -> void:
	var new_fog: Array[Vector2i] = []
	var new_memory: Array[Vector2i] = []
	if map != null:
		for c in _map_cells():
			if not _in_any_poly(GridUtil.cell_center_px(c), visible_polys):
				new_fog.append(c)
			if visited.has(c):
				new_memory.append(c)
	if new_fog == fog_cells and new_memory == memory_cells:
		return
	fog_cells = new_fog
	memory_cells = new_memory
	var kids := get_children()
	for s in kids:
		s.free()
	_rebuild_shapes()


func _rebuild_shapes() -> void:
	if map == null:
		return
	for c in fog_cells:
		add_child(_make_shape(c, FOG_COLOR))
	for c in memory_cells:
		add_child(_make_shape(c, MEMORY_COLOR))


func _make_shape(c: Vector2i, color: Color) -> Polygon2D:
	var shape := Polygon2D.new()
	shape.set_polygon(_cell_rect_points(c))
	shape.color = color
	return shape


func _cell_rect_points(c: Vector2i) -> PackedVector2Array:
	var rect := GridUtil.cell_rect_px(c)
	var e := Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y)
	var p := PackedVector2Array()
	p.append(rect.position)
	p.append(Vector2(e.x, rect.position.y))
	p.append(e)
	p.append(Vector2(rect.position.x, e.y))
	return p


func _in_any_poly(p: Vector2, polys: Array) -> bool:
	for poly in polys:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


func _map_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(map.height_cells):
		for x in range(map.width_cells):
			out.append(Vector2i(x, y))
	return out
