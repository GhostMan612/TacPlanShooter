# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name LockstepSession
extends Node


const PORT: int = 7600


var peer: ENetMultiplayerPeer = null
var local_faction_id: int = 0
var pending_inputs: Array = []
var last_sync_hash: String = ""
var session_active := false


func host(faction_id: int) -> void:
	local_faction_id = faction_id
	peer = ENetMultiplayerPeer.new()
	peer.create_host(PORT, 4)
	multiplayer.multiplayer_peer = peer
	session_active = true


func connect_client(address: String) -> void:
	local_faction_id = 1
	peer = ENetMultiplayerPeer.new()
	peer.create_client(address, PORT)
	multiplayer.multiplayer_peer = peer
	session_active = true


func queue_input(op_id: int, move_dir: Vector2, aim_deg: float, fire_pressed: bool, use_slot: bool) -> void:
	if not session_active:
		return
	pending_inputs.append({
		"op_id": op_id,
		"move_dir": move_dir,
		"aim_deg": aim_deg,
		"fire_pressed": fire_pressed,
		"use_slot": use_slot,
	})


func process_tick() -> void:
	if not session_active or pending_inputs.is_empty():
		return
	pending_inputs.pop_front()


func sync_tick_hash(hash: String) -> void:
	last_sync_hash = hash
