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
var last_sync_hash: String = ""
var session_active := false
var ticks_since_sync := 0


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


func process_tick(world: SimWorld) -> void:
	ticks_since_sync += 1
	if not session_active or pending_inputs.is_empty():
		return
	var now := world.tick + SimConstants.LOCKSTEP_INPUT_DELAY_TICKS
	for inp in pending_inputs:
		var oc := OverrideCommand.new()
		oc.tick = now
		oc.op_id = int(inp["op_id"])
		oc.move_dir = Vector2(inp["move_dir"].x, inp["move_dir"].y)
		oc.aim_deg = float(inp["aim_deg"])
		oc.fire_pressed = bool(inp["fire_pressed"])
		oc.use_slot = bool(inp["use_slot"])
		world.apply_override(oc)
	pending_inputs.clear()
	if ticks_since_sync >= HASH_SYNC_EVERY:
		ticks_since_sync = 0
		sync_tick_hash(world.state_hash())


func poll() -> void:
	if not session_active or peer == null:
		return
	peer.poll()
	while peer.get_available_packet_count() > 0:
		var data := peer.get_packet()
		if peer.get_packet_peer() == null or data.size() == 0:
			continue
		var inp: Variant = JSON.parse_string(data.get_string_from_ascii())
		if inp == null:
			continue
		pending_inputs.append(inp)


func sync_tick_hash(hash: String) -> void:
	last_sync_hash = hash
