# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name SquadHud
extends Control


signal operative_selected(op_id: int)


const HEIGHT_PX := 200
const DOT_PX := 22.0


var world: SimWorld = null
var squads: SquadConfig = null
var selected_op: int = -1
var active_faction_id: int = 0
var palette: Dictionary = ThemeManager.palette_for(ThemeManager.Style.DARK_TACTICAL)
var _row: HBoxContainer = null
var _cp_label: Label = null
var _op_buttons: Dictionary = {}
var _op_dots: Dictionary = {}
var _roster_key := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row = HBoxContainer.new()
	_row.name = "Squads"
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rebuild()


func place(rect: Rect2) -> void:
	position = rect.position
	size = rect.size


func apply_palette(p: Dictionary) -> void:
	palette = p
	if _cp_label != null:
		_cp_label.add_theme_color_override("font_color", palette["ink"])
	_update_live()


func refresh(w: SimWorld) -> void:
	world = w
	if _roster_signature() != _roster_key:
		_rebuild()
	else:
		_update_live()


func squad_of(op_id: int) -> StringName:
	if squads != null:
		for sq in SquadConfig.SQUADS:
			if squads.members(sq).has(op_id):
				return sq
	return SquadConfig.SQUADS[posmod(op_id, SquadConfig.SQUADS.size())]


func world_ops_of(squad: StringName) -> Array[SimOperative]:
	var out: Array[SimOperative] = []
	if world == null:
		return out
	for o in world.operatives:
		if o.faction_id == active_faction_id and squad_of(o.id) == squad:
			out.append(o)
	return out


func callsign(op_id: int) -> String:
	var sq := squad_of(op_id)
	var ops: Array[SimOperative] = []
	if world != null:
		for o in world.operatives:
			if squad_of(o.id) == sq:
				ops.append(o)
	for i in range(ops.size()):
		if ops[i].id == op_id:
			var prefix := "Y" if sq == &"gold" else String(sq).substr(0, 1).to_upper()
			return prefix + str(i + 1)
	return "?" + str(op_id)


func world_tapin_points() -> int:
	if world == null:
		return 0
	return int(world.tapin_points)


func health_color(o: SimOperative) -> Color:
	if not o.is_alive():
		return Color(0.863, 0.149, 0.149)
	if o.health == &"wounded":
		return Color(0.961, 0.620, 0.043)
	return Color(0.086, 0.639, 0.290)


func touch_operative(op_id: int) -> void:
	selected_op = op_id
	_update_live()
	operative_selected.emit(op_id)


func card_count() -> int:
	if _row == null:
		return 0
	return _row.get_child_count() - (1 if _cp_label != null else 0)


func operative_button(op_id: int) -> Button:
	return _op_buttons.get(op_id, null)


func _roster_signature() -> String:
	if world == null:
		return ""
	var parts: Array[String] = [str(active_faction_id)]
	for o in world.operatives:
		if o.faction_id == active_faction_id:
			parts.append("%d:%s" % [o.id, String(squad_of(o.id))])
	return ",".join(PackedStringArray(parts))


func _active_op_count() -> int:
	if world == null:
		return 0
	var n := 0
	for o in world.operatives:
		if o.faction_id == active_faction_id:
			n += 1
	return n


func _rebuild() -> void:
	_roster_key = _roster_signature()
	_op_buttons.clear()
	_op_dots.clear()
	_cp_label = null
	if _row == null:
		return
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	var total_ops := _active_op_count()
	var btn_w := 176.0
	var f_px := 26
	if total_ops == 3:
		btn_w = 120.0
		f_px = 22
	elif total_ops >= 4:
		btn_w = 92.0
		f_px = 18
	for sq in SquadConfig.SQUADS:
		var ops := world_ops_of(sq)
		if ops.is_empty():
			continue
		var card := PanelContainer.new()
		card.name = "Squad_" + String(sq)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		_row.add_child(card)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		card.add_child(col)
		var header := Label.new()
		header.text = String(sq).to_upper()
		header.add_theme_color_override("font_color", PlanBoard.squad_color(sq))
		header.add_theme_font_size_override("font_size", 28 if total_ops <= 2 else 22)
		col.add_child(header)
		var buttons := HBoxContainer.new()
		col.add_child(buttons)
		for o in ops:
			var b := Button.new()
			b.name = "Op%d" % o.id
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(btn_w, 96)
			b.clip_text = true
			b.add_theme_font_size_override("font_size", f_px)
			b.add_theme_color_override("font_color", PlanBoard.squad_color(sq))
			b.pressed.connect(touch_operative.bind(o.id))
			var dot := ColorRect.new()
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dot.position = Vector2(8, 8)
			dot.size = Vector2(DOT_PX if total_ops <= 2 else 16.0, DOT_PX if total_ops <= 2 else 16.0)
			b.add_child(dot)
			buttons.add_child(b)
			_op_buttons[o.id] = b
			_op_dots[o.id] = dot
	_cp_label = Label.new()
	_cp_label.name = "CommandPoints"
	_cp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cp_label.add_theme_color_override("font_color", palette["ink"])
	_cp_label.add_theme_font_size_override("font_size", 24 if total_ops <= 2 else 20)
	_row.add_child(_cp_label)
	_update_live()


func _update_live() -> void:
	if _cp_label != null:
		_cp_label.text = "CP %d/%d" % [world_tapin_points(), SimConstants.TAPIN_COMMAND_POINTS_MAX]
	if world == null:
		return
	for o in world.operatives:
		if not _op_buttons.has(o.id):
			continue
		var b: Button = _op_buttons[o.id]
		var dot: ColorRect = _op_dots[o.id]
		var status := ""
		if not o.is_alive():
			status = " KIA"
		elif o.halted:
			status = " HALT"
		elif o.done:
			status = " DONE"
		b.text = "   " + callsign(o.id) + status
		dot.color = health_color(o)
		b.modulate = Color(1, 1, 1, 1) if selected_op < 0 or selected_op == o.id else Color(1, 1, 1, 0.6)
