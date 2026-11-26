# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name LockstepSession
extends Node


const PORT: int = 7600
const HASH_SYNC_EVERY: int = 60


var peer: ENetMultiplayerPeer = null
var local_faction_id: int = 0
var pending_inputs: Array = []
var received_packets: Array[Dictionary] = []
var last_sync_hash: String = ""
var session_active := false
var ticks_since_sync := 0


func host(faction_id: int) -> void:
	host_on_port(faction_id, PORT)


func host_on_port(faction_id: int, port: int = PORT) -> int:
	close_session()
	local_faction_id = faction_id
	peer = ENetMultiplayerPeer.new()
	var err: int = peer.create_server(port, 4)
	if err == OK:
		if is_inside_tree() and multiplayer != null:
			multiplayer.multiplayer_peer = peer
		session_active = true
	return err


func connect_client(address: String) -> void:
	connect_on_port(address, PORT)


func connect_on_port(address: String, port: int = PORT) -> int:
	close_session()
	local_faction_id = 1
	peer = ENetMultiplayerPeer.new()
	var err: int = peer.create_client(address, port)
	if err == OK:
		if is_inside_tree() and multiplayer != null:
			multiplayer.multiplayer_peer = peer
		session_active = true
	return err


func close_session() -> void:
	if peer != null:
		peer.close()
	peer = null
	session_active = false
	pending_inputs.clear()
	received_packets.clear()


func is_peer_connected() -> bool:
	if not session_active or peer == null:
		return false
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func send_packet(payload: Dictionary) -> void:
	if not is_peer_connected():
		return
	var buf := JSON.stringify(payload).to_utf8_buffer()
	peer.put_packet(buf)


func queue_input(op_id: int, move_dir: Vector2, aim_deg: float, fire_pressed: bool, use_slot: bool) -> void:
	if not session_active:
		return
	var pkt := {
		"op_id": op_id,
		"move_dir": move_dir,
		"move_dir_x": move_dir.x,
		"move_dir_y": move_dir.y,
		"aim_deg": aim_deg,
		"fire_pressed": fire_pressed,
		"use_slot": use_slot,
	}
	pending_inputs.append(pkt)
	send_packet({
		"op_id": op_id,
		"move_dir_x": move_dir.x,
		"move_dir_y": move_dir.y,
		"aim_deg": aim_deg,
		"fire_pressed": fire_pressed,
		"use_slot": use_slot,
	})


func process_tick(world: SimWorld) -> void:
	ticks_since_sync += 1
	if not session_active or pending_inputs.is_empty():
		return
	var now := world.tick + SimConstants.LOCKSTEP_INPUT_DELAY_TICKS
	for inp in pending_inputs:
		var oc := OverrideCommand.new()
		oc.tick = now
		oc.op_id = int(inp["op_id"])
		if inp.has("move_dir") and inp["move_dir"] is Vector2:
			var mv: Vector2 = inp["move_dir"]
			oc.move_dir = Vector2(mv.x, mv.y)
		else:
			oc.move_dir = Vector2(float(inp.get("move_dir_x", 0.0)), float(inp.get("move_dir_y", 0.0)))
		oc.aim_deg = float(inp.get("aim_deg", 0.0))
		oc.fire_pressed = bool(inp.get("fire_pressed", false))
		oc.use_slot = bool(inp.get("use_slot", false))
		world.apply_override(oc)
	pending_inputs.clear()
	if ticks_since_sync >= HASH_SYNC_EVERY:
		ticks_since_sync = 0
		sync_tick_hash(world.state_hash())


func poll() -> void:
	if not session_active or peer == null:
		return
	if multiplayer == null or multiplayer.multiplayer_peer != peer:
		return
	peer.poll()
	while peer.get_available_packet_count() > 0:
		var data := peer.get_packet()
		if data.size() == 0:
			continue
		var inp: Variant = JSON.parse_string(data.get_string_from_utf8())
		if typeof(inp) != TYPE_DICTIONARY:
			continue
		var dict: Dictionary = inp
		if dict.has("kind"):
			received_packets.append(dict)
		elif dict.has("op_id"):
			pending_inputs.append(dict)


func sync_tick_hash(hash: String) -> void:
	last_sync_hash = hash
