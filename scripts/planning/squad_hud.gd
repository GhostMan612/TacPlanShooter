# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name SquadHud
extends Control


var world: SimWorld = null
var selected_op: int = -1


func _ready() -> void:
	custom_minimum_size = Vector2(get_viewport_rect().size.x, 120)
	position = Vector2(0, get_viewport_rect().size.y - 120)
	var x := 8.0
	for squad in SquadConfig.SQUADS:
		var box := HBoxContainer.new()
		box.position = Vector2(x, 8.0)
		box.size = Vector2(128.0, 104.0)
		var header := Label.new()
		header.text = String(squad)
		header.add_theme_color_override("color", PlanBoard.squad_color(squad))
		box.add_child(header)
		for o in world_ops_of(squad):
			var row := Button.new()
			row.text = "R" + str(o.id)
			row.size = Vector2(110.0, 30.0)
			row.add_theme_color_override("text_color", PlanBoard.squad_color(squad))
			row.button_down.connect(_on_row.bind(o.id))
			box.add_child(row)
			var dot := Label.new()
			dot.text = "●"
			dot.modulate = _health_dot_color(o)
			dot.add_theme_color_override("color", _health_dot_color(o))
			dot.position = Vector2(30.0, 8.0)
			row.add_child(dot)
		var cp := Label.new()
		cp.text = "CP: " + str(world_tapin_points())
		cp.position = Vector2(8.0, 56.0)
		box.add_child(cp)
		add_child(box)
		x += 140.0


func _on_row(op_id: int) -> void:
	touch_operative(op_id)


func world_tapin_points() -> int:
	if world == null:
		return 0
	return int(world.tapin_points)


func _health_dot_color(o: SimOperative) -> Color:
	if not o.is_alive():
		return Color.html("#DC2626")
	if o.health == &"wounded":
		return Color.html("#F59E0B")
	return Color.html("#16A34A")


func refresh(w: SimWorld) -> void:
	world = w


func touch_operative(op_id: int) -> void:
	selected_op = op_id


func world_ops_of(squad: StringName) -> Array:
	var out := []
	if world == null:
		return out
	for o in world.operatives:
		if o.faction_id == 0:
			out.append(o)
	return out
