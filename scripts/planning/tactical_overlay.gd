# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name TacticalOverlay
extends Node2D


const RING_LIFE_TICKS := 24
const DIAMOND_RADIUS := 7.0
const LABEL_SIZE := 7
const TICKS_PER_SEC := 60.0


var world: SimWorld = null
var local_faction_id := 0
var contacts: Dictionary = {}
var hostile_color := Color(0.94, 0.27, 0.27)
var ring_color := Color(1.0, 0.7, 0.0)
var ink := Color(0.9, 0.92, 0.95)


func apply_palette(pal: Dictionary) -> void:
	hostile_color = pal.get("red", hostile_color)
	ring_color = pal.get("amber", ring_color)
	ink = pal.get("ink", ink)
	queue_redraw()


func reset() -> void:
	contacts.clear()
	queue_redraw()


func update_contacts(w: SimWorld, live_polys_cells: Array) -> void:
	world = w
	if w == null:
		return
	for o in w.operatives:
		if o.faction_id == local_faction_id:
			continue
		var seen := false
		for poly in live_polys_cells:
			if Geometry2D.is_point_in_polygon(o.pos, poly):
				seen = true
				break
		if seen:
			contacts[o.id] = {"pos": o.pos, "tick": int(w.tick), "visible": true, "alive": o.is_alive()}
		elif contacts.has(o.id):
			var c: Dictionary = contacts[o.id]
			c["visible"] = false
	queue_redraw()


func visible_contacts() -> Array:
	var out := []
	for k in contacts.keys():
		if bool(contacts[k]["visible"]):
			out.append(k)
	return out


func lkp_contacts() -> Array:
	var out := []
	for k in contacts.keys():
		if not bool(contacts[k]["visible"]):
			out.append(k)
	return out


func seconds_since_contact(id: int) -> float:
	if world == null or not contacts.has(id):
		return -1.0
	return float(int(world.tick) - int(contacts[id]["tick"])) / TICKS_PER_SEC


static func diamond(center: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(center + Vector2(0, -r))
	pts.append(center + Vector2(r, 0))
	pts.append(center + Vector2(0, r))
	pts.append(center + Vector2(-r, 0))
	return pts


func _draw() -> void:
	if world == null:
		return
	var s := float(SimConstants.GRID_CELL_SIZE_PX)
	var now := int(world.tick)
	for ring in world.ai.acoustic_rings():
		var age := now - int(ring["tick"])
		if age < 0 or age > RING_LIFE_TICKS:
			continue
		var center := GridUtil.cell_center_px(ring["cell"])
		var a := 1.0 - float(age) / float(RING_LIFE_TICKS)
		draw_arc(center, 6.0 + (1.0 - a) * 20.0, 0.0, TAU, 32, Color(ring_color.r, ring_color.g, ring_color.b, a * 0.9), 1.5)
	var font := ThemeDB.fallback_font
	for k in contacts.keys():
		var c: Dictionary = contacts[k]
		var px: Vector2 = c["pos"] * s
		var pts := diamond(px, DIAMOND_RADIUS)
		var closed := pts.duplicate()
		closed.append(pts[0])
		if bool(c["visible"]):
			if bool(c["alive"]):
				draw_colored_polygon(pts, Color(hostile_color.r, hostile_color.g, hostile_color.b, 0.85))
			draw_polyline(closed, hostile_color.lightened(0.3), 1.5)
			if not bool(c["alive"]):
				draw_line(px + Vector2(-4, -4), px + Vector2(4, 4), hostile_color, 1.5)
				draw_line(px + Vector2(4, -4), px + Vector2(-4, 4), hostile_color, 1.5)
		else:
			var age_sec := seconds_since_contact(int(k))
			var fade := clampf(1.0 - age_sec / 20.0, 0.25, 1.0)
			draw_polyline(closed, Color(hostile_color.r, hostile_color.g, hostile_color.b, 0.7 * fade), 1.0)
			draw_string(font, px + Vector2(-DIAMOND_RADIUS, -DIAMOND_RADIUS - 2.0), "?%ds" % int(age_sec), HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, Color(ink.r, ink.g, ink.b, fade))
