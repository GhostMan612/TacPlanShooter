# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
extends SceneTree


var failures: int = 0


func _init() -> void:
	failures = 0


func _initialize() -> void:
	var version: String = String(ProjectSettings.get_setting("application/config/version", ""))
	_check(version == "1.0.0", "application/config/version == 1.0.0")
	var method: String = String(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	var method_mobile: String = String(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", ""))
	_check(method == "gl_compatibility" and method_mobile == "gl_compatibility", "gl_compatibility renderer desktop+mobile")
	_check(int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d", -1)) == 0, "msaa_2d == 0")
	_check(int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", -1)) == 0, "msaa_3d == 0")
	var save := ProgressionSave.load_from_string("{bad json")
	_check(save != null and save.profiles.is_empty(), "corrupt progression JSON falls back cleanly")
	var settings := ThemeManager.load_from_string("{bad json")
	_check(settings != null and int(settings.get("schema_version", 0)) == ThemeManager.SCHEMA_VERSION, "corrupt settings JSON falls back cleanly")
	for path in ["docs/PRIVACY-POLICY.md", "docs/RELEASE-SIGNING.md", "docs/store/PLAY-STORE-LISTING.md"]:
		_check(FileAccess.file_exists("res://" + path), "release doc exists: " + path)
	print("[HARNESS] RESULT %s failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print("[HARNESS] %s %s" % ["OK" if ok else "FAIL", what])
