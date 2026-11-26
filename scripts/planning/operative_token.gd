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
const RADIUS := 6.5
const CONE_RANGE := 26.0
const CONE_HALF_DEG := 35.0
const CONE_STEPS := 8
const LABEL_SIZE := 7
const HD_RIG_PATH := "res://addons/godot4-asset-vault/tacplanshooter_hd/scenes/modular_operative.tscn"


var op_id := -1
var selected := false
var routing_highlight := false
var sprite_texture: Texture2D = null
var squad_color := BASE_COLOR
var callsign := ""
var facing_deg := 0.0
var status: StringName = &"ready"
var ink := Color(0.9, 0.92, 0.95)
var hd_rig: Node2D = null


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
	_ensure_hd_rig()
	queue_redraw()


func _ensure_hd_rig() -> void:
	if hd_rig != null or not ResourceLoader.exists(HD_RIG_PATH):
		return
	var ps := ResourceLoader.load(HD_RIG_PATH, "PackedScene") as PackedScene
	if ps == null:
		return
	hd_rig = ps.instantiate() as Node2D
	if hd_rig == null:
		return
	add_child(hd_rig)
	var squad_idx := 0
	if squad_color != BASE_COLOR:
		squad_idx = int(squad_color.r * 255.0) % 4
	if hd_rig.has_method("configure"):
		hd_rig.call("configure", squad_idx, StringName(callsign), &"standard", &"smg")


func sync_from(o: SimOperative, px_pos: Vector2) -> bool:
	var st := status_of(o)
	var changed := st != status or absf(o.facing_deg - facing_deg) > 0.01
	position = px_pos
	facing_deg = o.facing_deg
	status = st
	if changed:
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


func _draw() -> void:
	var alive := status != &"kia"
	var body := squad_color if alive else KIA_COLOR
	if alive:
		draw_colored_polygon(cone_points(), Color(squad_color.r, squad_color.g, squad_color.b, 0.16))
		var dir := Vector2.from_angle(deg_to_rad(facing_deg))
		draw_line(dir * RADIUS * 0.6, dir * (RADIUS + 4.0), ink, 1.5)
	if sprite_texture != null:
		draw_texture_rect(sprite_texture, Rect2(Vector2(-RADIUS, -RADIUS), Vector2(RADIUS, RADIUS) * 2.0), false)
	else:
		draw_circle(Vector2.ZERO, RADIUS, body)
	var highlighted := selected or routing_highlight
	var outline := SELECTED_COLOR if highlighted else body.darkened(0.45)
	draw_arc(Vector2.ZERO, RADIUS + 1.2, 0.0, TAU, 24, outline, 2.0 if highlighted else 1.2)
	if status == &"halted" or status == &"blocked":
		draw_arc(Vector2.ZERO, RADIUS + 3.6, 0.0, TAU, 24, WARN_COLOR, 1.4 if status == &"halted" else 0.8)
	elif status == &"done":
		draw_circle(Vector2.ZERO, RADIUS * 0.35, ink)
	elif status == &"kia":
		var k := RADIUS * 0.7
		draw_line(Vector2(-k, -k), Vector2(k, k), KIA_MARK_COLOR, 1.6)
		draw_line(Vector2(k, -k), Vector2(-k, k), KIA_MARK_COLOR, 1.6)
	if callsign != "":
		draw_string(ThemeDB.fallback_font, Vector2(-RADIUS, -RADIUS - 3.0), callsign, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, ink)
