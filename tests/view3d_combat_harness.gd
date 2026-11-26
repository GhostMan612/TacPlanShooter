# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
extends SceneTree


var failures: int = 0


func _init() -> void:
	failures = 0


func _initialize() -> void:
	await _check_raycast_roundtrip()
	await _check_world_view_build()
	print("[VIEW3D] RESULT %s failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print("[VIEW3D] %s %s" % ["OK" if ok else "FAIL", what])


func _check_raycast_roundtrip() -> void:
	var cam := TacticalCamera3D.new()
	root.add_child(cam)
	cam.set_active(true)
	var cells := [Vector2i(4, 4), Vector2i(12, 8), Vector2i(24, 16)]
	var yaws := [0.0, 90.0, 180.0, 270.0]
	for tier in [0, 1, 2]:
		cam.set_tier(tier)
		for yaw in yaws:
			cam.yaw_deg = yaw
			cam.target_yaw = yaw
			cam.focus(Vector3(24.0, 0.0, 18.0))
			cam._apply()
			for cell in cells:
				var center := TouchRaycaster3D.cell_center(cell, 0)
				var screen := cam.unproject_position(center)
				var got := TouchRaycaster3D.screen_to_cell(cam, screen, 0, Vector2(720.0, 1612.0))
				_check(got == cell, "raycast tier=%d yaw=%.0f cell=%s -> %s" % [tier, yaw, str(cell), str(got)])
	root.remove_child(cam)
	cam.free()
	await process_frame


func _check_world_view_build() -> void:
	for path in ["res://data/maps/op01_glass_house.json", "res://data/maps/op05_penthouse_lock.json"]:
		var m := MapLoader.load_from_json(path)
		var w := SimWorld.new()
		w.setup(m, 1337)
		var view := WorldView3D.new()
		root.add_child(view)
		view.setup(w, m, 0, Vector2(720.0, 1612.0))
		_check(view.get_child_count() > 0, "builds 3D view for " + path)
		_check(view.vfx != null and view.fog_overlay != null, "vfx + fog overlay active for " + path)
		view.update_routes({&"red": [Vector2i(2, 2), Vector2i(3, 2)]})
		_check(view.route_overlay.get_child_count() >= 3, "route overlay built for " + path)
		root.remove_child(view)
		view.free()
		await process_frame
