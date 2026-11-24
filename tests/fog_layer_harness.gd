# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
extends SceneTree


var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var map := GreyboxMap.new()
	map.width_cells = 6
	map.height_cells = 4
	var door := Vector2i(3, 1)
	map.door_cells[door] = true
	map.door_open[door] = false
	for y in range(map.height_cells):
		var cell := Vector2i(3, y)
		if cell != door:
			map.solid_cells[cell] = true
	var world := SimWorld.new()
	world.setup(map, 42)
	world.add_operative(0, Vector2i(1, 1), [])
	world.add_operative(1, Vector2i(1, 2), [])
	var first := world.operatives[0]
	var second := world.operatives[1]
	var fog := FogLayer.new()
	fog.setup(world.map)
	root.add_child(fog)
	var behind := Vector2(4.5, 1.5)
	fog.update_visibility(world, 0)

	var live := fog._live_shapes[0]
	var closed_poly: PackedVector2Array = live.polygon
	_check(not Geometry2D.is_point_in_polygon(behind, closed_poly), "closed door occludes live mask")
	_check(fog._pending_memory == 2 and fog._memory_shapes[0].polygon == closed_poly, "memory stamps full observer polygons")
	for i in range(120):
		fog.update_visibility(world, 0)
	_check(fog._pending_memory == 2 and fog.memory_vp.get_child_count() == 2 and live == fog._live_shapes[0], "120 stationary updates preserve the initial two stamps and live nodes")

	fog._retire_memory_shapes()
	first.pos.x += 0.125
	fog.update_visibility(world, 0)
	_check(fog._pending_memory == 1, "moving one observer stamps one polygon")
	_check(fog._live_shapes[0] == live and fog._memory_shapes[0].polygon == live.polygon, "new polygon reuses mask shapes")
	var first_move: PackedVector2Array = live.polygon
	first.pos.y += 0.125
	fog.update_visibility(world, 0)
	_check(fog._pending_memory == 2 and fog._memory_shapes[0].polygon == first_move and fog._memory_shapes[1].polygon == live.polygon, "multiple physics updates preserve every stamp until the render completes")

	fog._retire_memory_shapes()
	world.map.open_door(door)
	fog.update_visibility(world, 0)
	_check(Geometry2D.is_point_in_polygon(behind, live.polygon) and fog._pending_memory == 2, "door change refreshes both observers and reveals through the opening")

	fog._retire_memory_shapes()
	second.health = &"kia"
	fog.update_visibility(world, 0)
	_check(fog._pending_memory == 0 and not fog._live_shapes[1].visible, "observer loss hides live shape and leaves visited buffer intact")
	fog.reset_fog()
	_check(fog.memory_vp.render_target_clear_mode == SubViewport.CLEAR_MODE_ONCE and fog.memory_vp.render_target_update_mode == SubViewport.UPDATE_ONCE, "reset schedules a clear of the visited buffer")
	_check(not live.visible and not fog._memory_shapes[0].visible and fog._pending_memory == 0, "reset clears active and queued mask shapes")
	fog.update_visibility(world, 0)
	_check(fog._pending_memory == 1 and live.visible, "first update after reset reveals current position again")
	fog.free()
	print("[FOG] RESULT %s failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures else 0)


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("[FOG] %s %s" % ["PASS" if ok else "FAIL", label])
