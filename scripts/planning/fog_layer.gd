# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name FogLayer
extends Node2D


const MEMORY_ALPHA := 0.5
const UNSEEN_ALPHA := 0.85


var map: GreyboxMap = null
var live_vp: SubViewport = null
var memory_vp: SubViewport = null
var active := false
var _comp: ColorRect = null
var _live_pool: Array[Polygon2D] = []
var _memory_pool: Array[Polygon2D] = []


func setup(m: GreyboxMap) -> void:
	map = m
	var w := int(float(map.width_cells) * float(SimConstants.GRID_CELL_SIZE_PX))
	var h := int(float(map.height_cells) * float(SimConstants.GRID_CELL_SIZE_PX))
	live_vp = _make_viewport(w, h, SubViewport.CLEAR_MODE_ALWAYS)
	memory_vp = _make_viewport(w, h, SubViewport.CLEAR_MODE_ONCE)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/planning/fog_mask.gdshader")
	_comp = ColorRect.new()
	_comp.size = Vector2(w, h)
	_comp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_comp.material = mat
	mat.set_shader_parameter("live_tex", live_vp.get_texture())
	mat.set_shader_parameter("memory_tex", memory_vp.get_texture())
	add_child(_comp)
	apply_palette(ThemeManager.palette_for(ThemeManager.Style.DARK_TACTICAL))
	set_active(false)


func _make_viewport(w: int, h: int, clear_mode: int) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.msaa_2d = Viewport.MSAA_DISABLED
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_clear_mode = clear_mode
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	return vp


func apply_palette(pal: Dictionary) -> void:
	if _comp == null:
		return
	var unseen: Color = pal.get("bg", Color(0.1, 0.11, 0.14))
	var mat := _comp.material as ShaderMaterial
	mat.set_shader_parameter("unseen_color", Color(unseen.r, unseen.g, unseen.b, UNSEEN_ALPHA))
	mat.set_shader_parameter("memory_color", Color(unseen.r, unseen.g, unseen.b, UNSEEN_ALPHA * MEMORY_ALPHA))


func set_active(on: bool) -> void:
	active = on
	visible = on
	var mode := SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if live_vp != null:
		live_vp.render_target_update_mode = mode
	if memory_vp != null:
		memory_vp.render_target_update_mode = mode


func update_polys(px_polys: Array) -> void:
	_fill_pool(live_vp, _live_pool, px_polys)
	_fill_pool(memory_vp, _memory_pool, px_polys)


func shape_count() -> int:
	var n := 0
	for p in _live_pool:
		if p.visible:
			n += 1
	return n


func pool_size() -> int:
	return _live_pool.size() + _memory_pool.size()


func _fill_pool(vp: SubViewport, pool: Array[Polygon2D], px_polys: Array) -> void:
	if vp == null:
		return
	while pool.size() < px_polys.size():
		var shape := Polygon2D.new()
		shape.color = Color.WHITE
		shape.antialiased = false
		vp.add_child(shape)
		pool.append(shape)
	for i in range(pool.size()):
		var shape := pool[i]
		if i < px_polys.size():
			shape.polygon = px_polys[i]
			shape.visible = true
		else:
			shape.visible = false


func reset_fog() -> void:
	update_polys([])
	if memory_vp != null:
		memory_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	set_active(false)
