# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name SplashScreen
extends Control


const SPLASH_SEC := 1.8


var _done := false
var _timer: Timer = null


func _ready() -> void:
	var tm := ThemeManager.apply_saved()
	var settings := ThemeManager.load_settings()
	BusGraph.apply_volumes(settings)
	var pal := tm.palette()
	var col := UiKit.build_screen(self, pal)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(UiKit.spacer(520))
	col.add_child(UiKit.heading("TACPLAN", pal, 132))
	col.add_child(UiKit.heading("SHOOTER", pal, 72))
	col.add_child(UiKit.caption("C4I TACTICAL PLANNING TERMINAL", pal))
	col.add_child(UiKit.spacer(240))
	col.add_child(UiKit.caption("TAP TO SKIP", pal))
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = SPLASH_SEC
	_timer.timeout.connect(_advance)
	add_child(_timer)
	_timer.start()
	print("[TacPlan] screen=splash theme=%d" % tm.current)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_advance()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_advance()
	elif event is InputEventKey and (event as InputEventKey).pressed:
		_advance()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()


func _advance() -> void:
	if _done:
		return
	_done = true
	if _timer != null:
		_timer.stop()
	ScreenRouter.goto_stage(ScreenRouter.Stage.TITLE)
