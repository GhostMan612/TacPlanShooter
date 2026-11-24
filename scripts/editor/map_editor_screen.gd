# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name MapEditorScreen
extends Control


const EXPORT_DIR := "user://custom_maps"
const EXPORT_PATH := "user://custom_maps/custom_map.json"
const BUFFER_PARAM := "editor_buffer"
const LABEL_GUTTER_PX := 32.0
const PAINT_TOOLS := [
	MapEditorState.Tool.WALL, MapEditorState.Tool.DOOR, MapEditorState.Tool.ZONES,
	MapEditorState.Tool.UNITS, MapEditorState.Tool.ERASE,
]
const ACTION_TOOLS := [
	MapEditorState.Tool.UNDO, MapEditorState.Tool.REDO, MapEditorState.Tool.VALIDATE,
	MapEditorState.Tool.PLAYTEST, MapEditorState.Tool.EXPORT, MapEditorState.Tool.IMPORT,
]


class EditorOverlay extends Node2D:
	var cells: Array = []
	var color := Color(0.9, 0.1, 0.1, 0.5)

	func _process(_delta: float) -> void:
		if not cells.is_empty():
			queue_redraw()

	func _draw() -> void:
		if cells.is_empty():
			return
		var pulse := 0.35 + 0.25 * sin(float(Time.get_ticks_msec() % 1000) * 0.00628)
		var c := Color(color.r, color.g, color.b, pulse)
		for cell in cells:
			var v := MapEditorValidator.cell_of(cell)
			draw_rect(GridUtil.cell_rect_px(v), c, true)


var state: MapEditorState = MapEditorState.new()
var renderer: MapRenderer = MapRenderer.new()
var overlay: EditorOverlay = EditorOverlay.new()
var invalid_cells: Array = []
var settings: Dictionary = {}
var palette: Dictionary = {}
var tool_buttons: Dictionary = {}
var status_label: Label = null
var canvas: Control = null
var _map_scale := 1.0
var _stroke: Dictionary = {}


static func tool_name(t: int) -> String:
	var names: Array = MapEditorState.Tool.keys()
	if t < 0 or t >= names.size():
		return "?"
	return String(names[t])


static func with_perimeter(w: int, h: int) -> GreyboxMap:
	var m := GreyboxMap.new()
	m.width_cells = w
	m.height_cells = h
	for x in range(w):
		m.solid_cells[Vector2i(x, 0)] = true
		m.solid_cells[Vector2i(x, h - 1)] = true
	for y in range(h):
		m.solid_cells[Vector2i(0, y)] = true
		m.solid_cells[Vector2i(w - 1, y)] = true
	return m


func _ready() -> void:
	var tm := ThemeManager.apply_saved()
	settings = ThemeManager.load_settings()
	palette = tm.palette()
	var buffer: Variant = ScreenRouter.get_param(BUFFER_PARAM, null)
	ScreenRouter.clear_param(BUFFER_PARAM)
	if buffer is MapEditorState:
		state = buffer as MapEditorState
	else:
		state.map = with_perimeter(16, 12)
	_build_ui()
	renderer.apply_palette(palette)
	_rebind_map()
	_set_tool(state.current_tool)
	get_viewport().size_changed.connect(_layout_canvas)
	print("[TacPlan] screen=map_editor w=%d h=%d" % [state.map.width_cells, state.map.height_cells])


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = palette["bg"]
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.name = "Root"
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_right = -24
	root.offset_top = 96
	root.offset_bottom = -48
	var top := HBoxContainer.new()
	root.add_child(top)
	var back := UiKit.button("< BACK", _go_back, settings)
	back.size_flags_horizontal = Control.SIZE_FILL
	back.custom_minimum_size.x = 240
	top.add_child(back)
	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(status_label)
	canvas = Control.new()
	canvas.name = "Canvas"
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.clip_contents = true
	canvas.gui_input.connect(_on_canvas_input)
	canvas.resized.connect(_layout_canvas)
	root.add_child(canvas)
	canvas.add_child(renderer)
	canvas.add_child(overlay)
	var group := ButtonGroup.new()
	var paint_grid := GridContainer.new()
	paint_grid.columns = 3
	root.add_child(paint_grid)
	for t in PAINT_TOOLS:
		var b := UiKit.button(tool_name(t), _set_tool.bind(t), settings)
		b.toggle_mode = true
		b.button_group = group
		b.name = "Tool_" + tool_name(t)
		tool_buttons[t] = b
		paint_grid.add_child(b)
	var action_grid := GridContainer.new()
	action_grid.columns = 3
	root.add_child(action_grid)
	for t in ACTION_TOOLS:
		var b := UiKit.button(tool_name(t), _run_action.bind(t), settings)
		b.name = "Action_" + tool_name(t)
		tool_buttons[t] = b
		action_grid.add_child(b)


func _rebind_map() -> void:
	renderer.setup(state.map)
	invalid_cells = []
	overlay.cells = []
	overlay.queue_redraw()
	_layout_canvas()


func _layout_canvas() -> void:
	if canvas == null or state == null or state.map == null:
		return
	var s := float(SimConstants.GRID_CELL_SIZE_PX)
	var world := Vector2(float(state.map.width_cells) * s + LABEL_GUTTER_PX, float(state.map.height_cells) * s + LABEL_GUTTER_PX)
	var avail := canvas.size
	if avail.x <= 1.0 or avail.y <= 1.0:
		return
	_map_scale = maxf(0.25, minf(avail.x / world.x, avail.y / world.y))
	var origin := Vector2(LABEL_GUTTER_PX * _map_scale, LABEL_GUTTER_PX * _map_scale)
	renderer.scale = Vector2.ONE * _map_scale
	renderer.position = origin
	overlay.scale = renderer.scale
	overlay.position = origin
	renderer.queue_redraw()
	overlay.queue_redraw()


func cell_at_canvas(local: Vector2) -> Vector2i:
	var s := float(SimConstants.GRID_CELL_SIZE_PX) * _map_scale
	var p := local - renderer.position
	return Vector2i(int(floor(p.x / s)), int(floor(p.y / s)))


func _on_canvas_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_stroke = {}
			apply_tool_at(cell_at_canvas(mb.position))
		else:
			_stroke = {}
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		if state.current_tool == MapEditorState.Tool.WALL or state.current_tool == MapEditorState.Tool.ERASE:
			apply_tool_at(cell_at_canvas(mm.position))


func apply_tool_at(c: Vector2i) -> bool:
	if not state.map.in_bounds(c) or _stroke.has(c):
		return false
	_stroke[c] = true
	var changed := false
	match state.current_tool:
		MapEditorState.Tool.WALL:
			if not state.map.solid_cells.has(c) or state.map.door_cells.has(c):
				state.paint_wall(c)
				changed = true
		MapEditorState.Tool.DOOR:
			if not state.map.door_cells.has(c):
				state.paint_door(c)
				changed = true
		MapEditorState.Tool.ZONES:
			if not _cell_in_zone(c):
				state.paint_zone(&"INSERTION", [[c.x, c.y]])
				changed = true
		MapEditorState.Tool.UNITS:
			if not _cell_has_objective(c):
				state.place_objective(c)
				changed = true
		MapEditorState.Tool.ERASE:
			changed = state.erase_cell(c)
	if changed:
		_after_edit("%s %s%02d" % [tool_name(state.current_tool), MapRenderer.col_letter(c.x), c.y + 1])
	return changed


func _cell_in_zone(c: Vector2i) -> bool:
	for z in state.map.insertion_zones:
		for zc in z.get("cells", []):
			if MapEditorValidator.cell_of(zc) == c:
				return true
	return false


func _cell_has_objective(c: Vector2i) -> bool:
	for o in state.map.objectives:
		if MapEditorValidator.cell_of(o) == c:
			return true
	return false


func _after_edit(msg: String) -> void:
	invalid_cells = []
	overlay.cells = []
	renderer.refresh()
	overlay.queue_redraw()
	_set_status(msg)


func _set_tool(t: int) -> void:
	state.current_tool = t
	var b: Button = tool_buttons.get(t, null)
	if b != null and not b.button_pressed:
		b.button_pressed = true
	_set_status("TOOL: " + tool_name(t))


func _run_action(t: int) -> void:
	match t:
		MapEditorState.Tool.UNDO:
			state.undo()
			_after_edit("UNDO")
		MapEditorState.Tool.REDO:
			state.redo()
			_after_edit("REDO")
		MapEditorState.Tool.VALIDATE:
			run_validate()
		MapEditorState.Tool.PLAYTEST:
			playtest()
		MapEditorState.Tool.EXPORT:
			export_map()
		MapEditorState.Tool.IMPORT:
			import_map()


func run_validate() -> Array:
	var flags := MapEditorValidator.validate(state.map, true)
	invalid_cells = []
	for f in flags:
		invalid_cells.append(f["cell"])
	overlay.cells = invalid_cells
	overlay.queue_redraw()
	if flags.is_empty():
		_set_status("VALID: map passes all checks")
	else:
		var first: Dictionary = flags[0]
		_set_status("%d ISSUE%s: %s" % [flags.size(), "" if flags.size() == 1 else "S", String(first["reason"])])
	return flags


func export_map() -> bool:
	DirAccess.make_dir_recursive_absolute(EXPORT_DIR)
	var f := FileAccess.open(EXPORT_PATH, FileAccess.WRITE)
	if f == null:
		_set_status("EXPORT FAILED")
		return false
	f.store_string(state.to_json())
	f.close()
	_set_status("EXPORTED: " + EXPORT_PATH)
	return true


func import_map() -> bool:
	if not FileAccess.file_exists(EXPORT_PATH):
		_set_status("NOTHING TO IMPORT: export a map first")
		return false
	var f := FileAccess.open(EXPORT_PATH, FileAccess.READ)
	if f == null:
		_set_status("IMPORT FAILED")
		return false
	var text := f.get_as_text()
	f.close()
	return _import_text(text)


func _import_text(text: String) -> bool:
	var imported := MapEditorState.from_json(text)
	if imported == null:
		_set_status("IMPORT FAILED: invalid map data")
		return false
	state = imported
	_stroke.clear()
	_rebind_map()
	_set_tool(MapEditorState.Tool.WALL)
	_set_status("IMPORTED: " + EXPORT_PATH)
	return true


func playtest() -> bool:
	var flags := run_validate()
	if not flags.is_empty():
		return false
	ScreenRouter.set_param(BUFFER_PARAM, state)
	ScreenRouter.set_param("map_json", state.to_json())
	ScreenRouter.set_param("return_stage", int(ScreenRouter.Stage.MAP_EDITOR))
	if ScreenRouter.goto_stage(ScreenRouter.Stage.IN_MISSION):
		return true
	ScreenRouter.clear_param(BUFFER_PARAM)
	ScreenRouter.clear_param("map_json")
	ScreenRouter.clear_param("return_stage")
	_set_status("PLAYTEST FAILED")
	return false


func _set_status(msg: String) -> void:
	if status_label != null:
		status_label.text = msg


func _go_back() -> void:
	ScreenRouter.goto_stage(ScreenRouter.Stage.TITLE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if UiKit.is_back_event(event):
		_go_back()
