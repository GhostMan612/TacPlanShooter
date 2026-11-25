# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name TacticalAudio
extends Node


signal squelch_played(name: StringName)
signal heartbeat_intensity(0.0..1.0)


const DUCK_SECONDS: float = 3.0
var _duck_until := -1
var _ambient_bus_idx := 0
var _heartbeat_hp_peak := 1.0


var _heartbeat_time_left := 0.0


func _ready() -> void:
	_setup_buses()
	EventBus.operative_damaged.connect(_on_operative_damaged)
	EventBus.breach_detonated.connect(_on_breach)
	EventBus.go_code_issued.connect(_on_go_code)


func _setup_buses() -> void:
	_ambient_bus_idx = _ensure_bus(&"Ambient")
	_ensure_bus(&"SFX")
	_ensure_bus(&"UI")


func _ensure_bus(name: StringName) -> int:
	for i in range(AudioServer.get_bus_count()):
		if AudioServer.get_bus_name(i) == name:
			return i
	var idx := AudioServer.add_bus()
	AudioServer.set_bus_name(idx, String(name))
	return idx


func _on_go_code(_code: StringName) -> void:
	_play_squelch(&"ui_squelch")
	squelch_played.emit(&"go_code")


func play_blip(name: StringName) -> void:
	var p := "res://assets/audio/" + String(name) + ".wav"
	if ResourceLoader.exists(p):
		var t := ResourceLoader.load(p, "AudioStream") as AudioStream
		if t != null:
			var pl := AudioStreamPlayer2D.new()
			pl.stream = t
			add_child(pl)
			pl.play()
			pl.call_deferred("queue_free")


func _on_breach(_pos: Vector2) -> void:
	_duck_ambient()
	_play_squelch(&"ui_squelch_strong")


func _on_operative_damaged(_op_id: int, remaining_hp: int) -> void:
	var h: float = float(remaining_hp) / 100.0
	if h > 0 and h < _heartbeat_hp_peak:
		_heartbeat_hp_peak = h
		_heartbeat_time_left = 12.0
	emit_signal(heartbeat_intensity, _heartbeat_hp_peak)


func _duck_ambient() -> void:
	AudioServer.set_bus_mute(_ambient_bus_idx, true)
	_duck_until = Time.get_ticks_msec() + int(DUCK_SECONDS * 1000.0)
	call_deferred("_unduck")


func _unduck() -> void:
	AudioServer.set_bus_mute(_ambient_bus_idx, false)


func _physics_process(_delta: float) -> void:
	if _heartbeat_time_left > 0:
		_heartbeat_time_left -= _delta
		if _heartbeat_time_left <= 0:
			_play_squelch(&"ui_heartbeat")
	if Time.get_ticks_msec() > _duck_until:
		AudioServer.set_bus_mute(_ambient_bus_idx, false)


func _play_squelch(name: StringName) -> void:
	var p := "res://assets/audio/" + String(name) + ".wav"
	var t := null
	if ResourceLoader.exists(p):
		t = ResourceLoader.load(p, "AudioStream") as AudioStream
	if t == null:
		return
	var pl := AudioStreamPlayer2D.new()
	pl.stream = t
	add_child(pl)
	pl.play()
	pl.call_deferred("queue_free")
