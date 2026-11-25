# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name TacticalVfx
extends Node2D


var _effects: Array[Dictionary] = []


func _process(delta: float) -> void:
	if _effects.is_empty():
		return
	var keep: Array[Dictionary] = []
	for e in _effects:
		var age := float(e["age"]) + delta
		if age < float(e["life"]):
			e["age"] = age
			keep.append(e)
	_effects = keep
	queue_redraw()


func clear() -> void:
	_effects.clear()
	queue_redraw()


func _push(kind: StringName, pos: Vector2, extra: Dictionary, life: float) -> void:
	var item := {"kind": kind, "pos": pos, "age": 0.0, "life": life}
	for k in extra.keys():
		item[k] = extra[k]
	_effects.append(item)
	queue_redraw()


func spawn_muzzle_flash(position: Vector2) -> void:
	_push(&"muzzle", position, {}, 0.12)


func spawn_bullet_tracer(from: Vector2, to: Vector2) -> void:
	_push(&"tracer", from, {"to": to}, 0.16)


func spawn_breach_shockwave(center: Vector2) -> void:
	_push(&"ring", center, {"color": Color(1.0, 0.62, 0.18), "r0": 3.0, "r1": 28.0}, 0.45)


func spawn_flashbang_bloom(center: Vector2) -> void:
	_push(&"bloom", center, {"color": Color(1.0, 0.98, 0.86), "r0": 6.0, "r1": 34.0}, 0.40)


func spawn_stun_ring(center: Vector2) -> void:
	_push(&"ring", center, {"color": Color(0.95, 0.9, 0.35), "r0": 4.0, "r1": 22.0}, 0.35)


func spawn_tear_gas_cloud(center: Vector2) -> void:
	_push(&"bloom", center, {"color": Color(0.55, 0.92, 0.45), "r0": 14.0, "r1": 32.0}, 1.40)


func spawn_acoustic_ring(center: Vector2, radius: float) -> void:
	_push(&"ring", center, {"color": Color(1.0, 0.72, 0.2), "r0": 4.0, "r1": maxf(radius, 14.0)}, 0.40)


func spawn_grid_scanlines() -> void:
	_push(&"scan", Vector2.ZERO, {}, 0.35)


func _draw() -> void:
	for e in _effects:
		var t := clampf(float(e["age"]) / maxf(float(e["life"]), 0.01), 0.0, 1.0)
		var a := 1.0 - t
		var k: StringName = e["kind"]
		var pos: Vector2 = e["pos"]
		if k == &"muzzle":
			draw_circle(pos, 5.5 * a + 1.5, Color(1.0, 0.88, 0.42, 0.9 * a))
		elif k == &"tracer":
			draw_line(pos, e["to"], Color(1.0, 0.82, 0.32, 0.85 * a), 1.4, false)
		elif k == &"bloom":
			var c: Color = e["color"]
			var rad := lerpf(float(e["r0"]), float(e["r1"]), t)
			draw_circle(pos, rad, Color(c.r, c.g, c.b, 0.42 * a))
		elif k == &"ring":
			var rc: Color = e["color"]
			var rrad := lerpf(float(e["r0"]), float(e["r1"]), t)
			draw_arc(pos, rrad, 0.0, TAU, 28, Color(rc.r, rc.g, rc.b, 0.85 * a), 1.8)
