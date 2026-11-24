# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name MapEditorScreen
extends Control


var state := MapEditorState.new()
var renderer := MapRenderer.new()
var invalid_cells := []
var _tool_bar: HBoxContainer = null


func _ready() -> void:
	renderer.setup(state.map)
	add_child(renderer)
	var br := Label.new()
	br.custom_minimum_size = Vector2(get_viewport_rect().size.x, 40)
	br.set_anchors_and_offsets(0, 0, 1, 1)
	add_child(br)
	var bar := HBoxContainer.new()
	bar.size = Vector2(get_viewport_rect().size.x, 36)
	bar.position = Vector2(0, get_viewport_rect().size.y - 36)
	_tool_bar = bar
	for t in MapEditorState.Tool:
		var b := Button.new()
		b.text = str(t)
		b.size = Vector2(80.0, 32.0)
		b.button_down.connect(_on_tool.bind(t))
		bar.add_child(b)
	add_child(bar)


func _on_tool(t: int) -> void:
	state.current_tool = t
	if t == MapEditorState.Tool.VALIDATE:
		invalid_cells = state.validate()
		queue_redraw()
	elif t == MapEditorState.Tool.UNDO:
		state.undo()
	elif t == MapEditorState.Tool.REDO:
		state.redo()


func _gui_input(ev: InputEvent) -> void:
	var evp: InputEventMouseButton = ev if ev is InputEventMouseButton
	if evp == null:
		return
	if evp.button_index != MOUSE_BUTTON_LEFT or evp.pressed:
		return
	var s := float(SimConstants.GRID_CELL_SIZE_PX)
	var local := evp.position - _tool_bar.position
	var c := Vector2i(int(local.x / s), int(local.y / s))
	if c.x < 0 or c.y < 0 or c.x >= state.map.width_cells or c.y >= state.map.height_cells:
		return
	match state.current_tool:
		MapEditorState.Tool.WALL:
			state.paint_wall(c)
		MapEditorState.Tool.DOOR:
			state.paint_door(c)
		MapEditorState.Tool.ZONES:
			state.paint_zone(&"INSERTION", [c])
		MapEditorState.Tool.UNITS:
			state.place_objective(c)
		MapEditorState.Tool.ERASE:
			_erase_at(c)
	queue_redraw()
	renderer.queue_redraw()


func _erase_at(c: Vector2i) -> void:
	state.map.solid_cells.erase(c)
	state.map.door_cells.erase(c)


func _draw() -> void:
	for c in invalid_cells:
		draw_rect(GridUtil.cell_rect_px(Vector2i(c[0], c[1])), Color(0.9, 0.1, 0.1, 0.45))
