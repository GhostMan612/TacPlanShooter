# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name AdaptiveBgm
extends Node


signal track_changed(name: StringName)


const TRACKS: Array[StringName] = [&"bgm_stealth_pad", &"bgm_caution_pulse", &"bgm_combat_alert"]
var track: int = 0
var _players: Array[AudioStreamPlayer] = []
var _bus := "BGM"


func _ready() -> void:
	for n in TRACKS:
		var p := AudioStreamPlayer.new()
		p.name = String(n)
		p.bus = _bus
		var path := "res://assets/audio/" + String(n) + ".wav"
		if ResourceLoader.exists(path):
			p.stream = ResourceLoader.load(path, "AudioStream") as AudioStream
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	_play(0)


func _play(idx: int) -> void:
	track = clampi(idx, 0, _players.size() - 1)
	for i in range(_players.size()):
		_players[i].volume_db = 0.0 if i == track else -80.0
		if i == track and not _players[i].playing:
			_players[i].play()
	track_changed.emit(TRACKS[track])


func set_state(state: int) -> void:
	_play(state)


func on_alert() -> void:
	_play(2)


func on_caution() -> void:
	_play(1)


func on_stealth() -> void:
	_play(0)
