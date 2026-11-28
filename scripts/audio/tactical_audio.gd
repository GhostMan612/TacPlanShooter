# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
extends Node


signal squelch_played(name: StringName)
signal heartbeat_intensity(level: float)


const DUCK_SECONDS: float = 3.0
const ADAPTIVE_BGM_SCRIPT := preload("res://scripts/audio/adaptive_bgm.gd")
const BUS_GRAPH_SCRIPT := preload("res://scripts/audio/bus_graph.gd")
const HEARTBEAT_INTERVAL_SEC: float = 1.2
const SFX_POOL_SLOTS: int = 3
var _duck_until: int = -1
var _duck_factor: float = 1.0
var _ambient_bus_idx: int = -1
var _heartbeat_hp_peak: float = 1.0
var _heartbeat_time_left: float = 0.0
var _heartbeat_pulse_cd: float = 0.0
var _rng := RandomNumberGenerator.new()
var bgm: Node = null
var _sfx_pool: Dictionary = {}
var _sfx_cursor: Dictionary = {}


func _ready() -> void:
	_rng.seed = 9001
	_setup_buses()
	bgm = ADAPTIVE_BGM_SCRIPT.new()
	bgm.name = "AdaptiveBgm"
	add_child(bgm)
	var eb := get_node_or_null("/root/EventBus")
	if eb != null:
		eb.operative_damaged.connect(_on_operative_damaged)
		eb.breach_detonated.connect(_on_breach)
		eb.go_code_issued.connect(_on_go_code)


func _setup_buses() -> void:
	BUS_GRAPH_SCRIPT.ensure_buses()
	_ambient_bus_idx = AudioServer.get_bus_index(&"Ambient")
	if _ambient_bus_idx >= 0 and AudioServer.get_bus_effect_count(_ambient_bus_idx) == 0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 18000.0
		AudioServer.add_bus_effect(_ambient_bus_idx, lp)


func _on_go_code(_code: StringName) -> void:
	_play_squelch(&"ui_squelch")
	squelch_played.emit(&"go_code")


func play_blip(sound_name: StringName = &"") -> void:
	var key := String(sound_name)
	if key == "" or not ResourceLoader.exists("res://assets/audio/" + key + ".wav"):
		key = "sfx_ui_blip_%02d" % _rng.randi_range(1, 4)
	_play_path("res://assets/audio/" + key + ".wav", &"RadioComms")


func _on_breach(_pos: Vector2) -> void:
	_duck_ambient(0.251)
	_play_path("res://assets/audio/sfx_breach_c4.wav", &"TacticalSFX")
	_play_squelch(&"ui_squelch_strong")
	squelch_played.emit(&"breach")


func play_gun(loud: bool) -> void:
	_play_path("res://assets/audio/sfx_gun_loud.wav" if loud else "res://assets/audio/sfx_gun_suppressed.wav", &"TacticalSFX")


func play_alert() -> void:
	_play_path("res://assets/audio/sfx_alert_sting.wav", &"TacticalSFX")
	if bgm != null:
		bgm.on_alert()


func play_context(kind: StringName) -> void:
	var names := {
		&"door_locked": "sfx_door_locked",
		&"debris": "sfx_dirt_debris",
		&"glass": "sfx_glass_break",
		&"barrel": "sfx_breach_c4",
	}
	if names.has(kind):
		_play_path("res://assets/audio/" + String(names[kind]) + ".wav", &"TacticalSFX")


func _duck_ambient(factor: float) -> void:
	_duck_factor = clampf(factor, 0.05, 1.0)
	_duck_until = Time.get_ticks_msec() + int(DUCK_SECONDS * 1000.0)
	if _ambient_bus_idx >= 0:
		AudioServer.set_bus_volume_db(_ambient_bus_idx, linear_to_db(_duck_factor))


func _unduck() -> void:
	_duck_factor = 1.0
	_duck_until = -1
	if _ambient_bus_idx >= 0:
		AudioServer.set_bus_volume_db(_ambient_bus_idx, 0.0)


func _on_operative_damaged(_op_id: int, remaining_hp: int) -> void:
	var h: float = clampf(float(remaining_hp) / 100.0, 0.0, 1.0)
	if h > 0.0 and h < _heartbeat_hp_peak:
		_heartbeat_hp_peak = h
		_heartbeat_time_left = 12.0
		_heartbeat_pulse_cd = 0.0
		_play_squelch(&"ui_heartbeat")
	heartbeat_intensity.emit(1.0 - _heartbeat_hp_peak)


func _physics_process(delta: float) -> void:
	if _duck_until >= 0 and Time.get_ticks_msec() >= _duck_until:
		_unduck()
	if _heartbeat_time_left > 0.0:
		_heartbeat_time_left = maxf(0.0, _heartbeat_time_left - delta)
		_heartbeat_pulse_cd -= delta
		if _heartbeat_pulse_cd <= 0.0:
			_heartbeat_pulse_cd = HEARTBEAT_INTERVAL_SEC
			_play_squelch(&"ui_heartbeat")
		if _heartbeat_time_left <= 0.0:
			_heartbeat_hp_peak = 1.0
	if _ambient_bus_idx >= 0:
		var lp: AudioEffectLowPassFilter = null
		var nfx := AudioServer.get_bus_effect_count(_ambient_bus_idx)
		for i in range(nfx):
			var e := AudioServer.get_bus_effect(_ambient_bus_idx, i)
			if e is AudioEffectLowPassFilter:
				lp = e as AudioEffectLowPassFilter
				break
		if lp != null:
			lp.cutoff_hz = 18000.0 if _heartbeat_time_left <= 0.0 else 850.0


func _play_squelch(kind: StringName) -> void:
	var path := ""
	if kind == &"ui_squelch":
		path = "res://assets/audio/sfx_ui_squelch_%02d.wav" % _rng.randi_range(1, 8)
	elif kind == &"ui_squelch_strong":
		path = "res://assets/audio/sfx_ui_squelch_strong.wav"
	elif kind == &"ui_heartbeat":
		path = "res://assets/audio/sfx_ui_heartbeat.wav"
	else:
		path = "res://assets/audio/" + String(kind) + ".wav"
	var bus := &"StressHeartbeat" if kind == &"ui_heartbeat" else &"RadioComms"
	_play_path(path, bus)


func _play_path(path: String, bus_name: StringName) -> void:
	if not is_inside_tree() or not ResourceLoader.exists(path):
		return
	var stream := ResourceLoader.load(path, "AudioStream") as AudioStream
	if stream == null:
		return
	if not _sfx_pool.has(bus_name):
		var arr: Array[AudioStreamPlayer] = []
		for i in range(SFX_POOL_SLOTS):
			var p := AudioStreamPlayer.new()
			p.bus = String(bus_name)
			add_child(p)
			arr.append(p)
		_sfx_pool[bus_name] = arr
		_sfx_cursor[bus_name] = 0
	var pool: Array[AudioStreamPlayer] = _sfx_pool[bus_name]
	var idx: int = int(_sfx_cursor[bus_name]) % SFX_POOL_SLOTS
	var pl := pool[idx]
	_sfx_cursor[bus_name] = idx + 1
	pl.stream = stream
	pl.play()
