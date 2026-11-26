# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name OperativeToken
extends Node2D


const BASE_COLOR := Color(0.55, 0.62, 0.7)
const SELECTED_COLOR := Color(0.25, 0.85, 1.0)
const KIA_COLOR := Color(0.45, 0.45, 0.48)
const WARN_COLOR := Color(0.96, 0.62, 0.04)
const KIA_MARK_COLOR := Color(0.86, 0.15, 0.15)
const RADIUS := 8.0
const CONE_RANGE := 28.0
const CONE_HALF_DEG := 35.0
const CONE_STEPS := 8
const LABEL_SIZE := 8
const FOOT_SHADOW := Color(0, 0, 0, 0.45)
const HOSTILE_UNIFORM := Color(0.55, 0.14, 0.16)
const HOSTILE_GEAR := Color(0.18, 0.20, 0.24)
const HOSTAGE_UNIFORM := Color(0.20, 0.62, 0.95)
const VISOR := Color(0.55, 0.95, 1.0)
const ARMOR := Color(0.34, 0.40, 0.48)


var op_id := -1
var selected := false
var routing_highlight := false
var sprite_texture: Texture2D = null
var squad_color := BASE_COLOR
var callsign := ""
var facing_deg := 0.0
var status: StringName = &"ready"
var ink := Color(0.9, 0.92, 0.95)
var hostile := false
var hostage := false
var bob_phase := 0.0
var _last_pos := Vector2.ZERO


func _init(p_id := -1) -> void:
	op_id = p_id


static func status_of(o: SimOperative) -> StringName:
	if not o.is_alive():
		return &"kia"
	if o.halted:
		return &"halted"
	if o.move_blocked_from != 0:
		return &"blocked"
	if o.done:
		return &"done"
	return &"ready"


func configure(color: Color, sign_text: String, ink_color: Color) -> void:
	squad_color = color
	callsign = sign_text
	ink = ink_color
	queue_redraw()


func sync_from(o: SimOperative, px_pos: Vector2) -> bool:
	var st := status_of(o)
	var changed := st != status or absf(o.facing_deg - facing_deg) > 0.01
	if px_pos.distance_to(_last_pos) > 0.1:
		bob_phase += 0.35
		_last_pos = px_pos
	position = px_pos
	facing_deg = o.facing_deg
	status = st
	hostile = o.faction_id != 0
	if changed:
		queue_redraw()
	queue_redraw()
	return changed


func set_selected(v: bool) -> void:
	selected = v
	queue_redraw()


func set_routing_highlight(v: bool) -> void:
	routing_highlight = v
	queue_redraw()


func set_sprite(t: Texture2D) -> void:
	sprite_texture = t
	queue_redraw()


func cone_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var a0 := deg_to_rad(facing_deg - CONE_HALF_DEG)
	var a1 := deg_to_rad(facing_deg + CONE_HALF_DEG)
	for i in range(CONE_STEPS + 1):
		var a := lerpf(a0, a1, float(i) / float(CONE_STEPS))
		pts.append(Vector2(cos(a), sin(a)) * CONE_RANGE)
	return pts


func _bob() -> float:
	return sin(bob_phase) * 1.5


func _uniform() -> Color:
	if hostage:
		return HOSTAGE_UNIFORM
	if hostile:
		return HOSTILE_UNIFORM
	return squad_color


func _draw() -> void:
	var alive := status != &"kia"
	var uniform := _uniform()
	if alive:
		draw_colored_polygon(cone_points(), Color(squad_color.r, squad_color.g, squad_color.b, 0.14))
	draw_circle(Vector2(0, 6), 8.0, FOOT_SHADOW)
	draw_arc(Vector2.ZERO, RADIUS + 3.0, 0.0, TAU, 24, squad_color, 2.0)
	var yoff := _bob() if alive else 0.0
	var body_col := _uniform() if alive else KIA_COLOR
	var gear := HOSTILE_GEAR if hostile else ARMOR
	var px := Vector2(0, yoff - 5.0)
	draw_rect(Rect2(px + Vector2(-5, -9), Vector2(10, 6)), gear, true)
	draw_rect(Rect2(px + Vector2(-6, -3), Vector2(12, 9)), body_col, true)
	draw_rect(Rect2(px + Vector2(-4, 1), Vector2(8, 4)), gear, true)
	draw_rect(Rect2(px + Vector2(-3, -8), Vector2(6, 2)), VISOR if alive else Color(0.3, 0.3, 0.3), true)
	var dir := Vector2.from_angle(deg_to_rad(facing_deg))
	var gun := dir * 13.0
	draw_line(px + dir * 3.0, px + gun, Color(0.08, 0.10, 0.13), 3.0)
	draw_line(px + dir * 3.0, px + gun, Color(0.62, 0.68, 0.75), 1.0)
	if hostage:
		draw_rect(Rect2(px + Vector2(-1, -12), Vector2(2, 3)), Color(1.0, 0.95, 0.6), true)
	if sprite_texture != null:
		draw_texture_rect(sprite_texture, Rect2(Vector2(-RADIUS, -RADIUS), Vector2(RADIUS, RADIUS) * 2.0), false)
	var highlighted := selected or routing_highlight
	var outline := SELECTED_COLOR if highlighted else body_col.darkened(0.4)
	draw_arc(Vector2.ZERO, RADIUS + 5.0, 0.0, TAU, 24, outline, 2.0 if highlighted else 1.0)
	if status == &"halted" or status == &"blocked":
		draw_arc(Vector2.ZERO, RADIUS + 7.0, 0.0, TAU, 24, WARN_COLOR, 1.4 if status == &"halted" else 0.8)
	elif status == &"done":
		draw_circle(Vector2.ZERO, RADIUS * 0.35, ink)
	elif status == &"kia":
		var k := RADIUS * 0.7
		draw_line(Vector2(-k, -k), Vector2(k, k), KIA_MARK_COLOR, 1.6)
		draw_line(Vector2(k, -k), Vector2(-k, k), KIA_MARK_COLOR, 1.6)
	if callsign != "":
		draw_string(ThemeDB.fallback_font, Vector2(-RADIUS, -RADIUS - 9.0), callsign, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, ink)
