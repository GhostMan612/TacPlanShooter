# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
extends Node2D

var map: GreyboxMap = null
var renderer: MapRenderer = null
var camera: MissionCamera = null
var controller: PlanningController = null


func _ready() -> void:
	var method: String = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	print("[TacPlan] boot OK phase=%s fps_cap=%d renderer=%s ticks_per_sec=%d" % [
		"PLANNING",
		Engine.max_fps,
		method,
		Engine.physics_ticks_per_second,
	])
	map = GreyboxMap.build_default()
	renderer = MapRenderer.new()
	renderer.setup(map)
	add_child(renderer)
	for spec in [[0, Vector2i(2, 2)], [1, Vector2i(13, 2)]]:
		var token := OperativeToken.new(int(spec[0]))
		token.position = GridUtil.cell_center_px(Vector2i(spec[1]))
		add_child(token)
	camera = MissionCamera.new()
	add_child(camera)
	camera.configure_for_map(
		Vector2(map.width_cells, map.height_cells) * float(SimConstants.GRID_CELL_SIZE_PX),
		get_viewport_rect().size
	)
	camera.make_current()
	controller = PlanningController.new()
	controller.camera = camera
	controller.line_container = self
	for child in get_children():
		if child is OperativeToken:
			controller.tokens.append(child as OperativeToken)
	add_child(controller)
