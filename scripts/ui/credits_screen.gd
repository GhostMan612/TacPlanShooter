# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name CreditsScreen
extends Control


const LINES: Array[String] = [
	"TACPLAN SHOOTER",
	"A top-down tactical planning game.",
	"Plan routes, stances and go-codes, then watch a deterministic 60 Hz simulation execute the plan.",
	"Built with Godot Engine 4 (Compatibility renderer).",
	"Tactical icon set generated in-repo by tools/generate_svg_assets.py.",
	"All operatives, units and operations are fictional.",
	"v1.0.0 — Godot 4 Compatibility renderer.",
	"Assets: godot4-asset-vault@v0.2.0 (CC0 / ORIGINAL_PROCEDURAL).",
	"Provenance: PROVENANCE.md — zero telemetry, offline-first.",
]


func _ready() -> void:
	var tm := ThemeManager.apply_saved()
	var settings := ThemeManager.load_settings()
	var pal := tm.palette()
	var col := UiKit.build_screen(self, pal)
	col.add_child(UiKit.button("< BACK", _go_back, settings))
	col.add_child(UiKit.heading("CREDITS", pal))
	for i in range(LINES.size()):
		col.add_child(UiKit.caption(LINES[i], pal, i == 0))
	print("[TacPlan] screen=credits")


func _go_back() -> void:
	ScreenRouter.goto_stage(ScreenRouter.Stage.TITLE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if UiKit.is_back_event(event):
		_go_back()
