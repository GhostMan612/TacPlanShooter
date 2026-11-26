# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name TwoPlayerScreen
extends Control


const MODES: Array[Dictionary] = [
	{
		"key": "pvp",
		"label": "ASYMMETRIC PVP  (BREACH VS DEFEND)",
		"desc": "P1 commands 2 Breachers (Red/Blue) from Insertion. P2 commands 2 Defenders (Green/Gold) inside the structure.",
	},
	{
		"key": "coop",
		"label": "CO-OP ASSAULT  (2-PLAYER BREACH)",
		"desc": "P1 commands Red 1 and P2 commands Blue 1 in a joint assault against GOAP CPU Defenders.",
	},
]


var settings: Dictionary = {}
var mode_index: int = 0
var map_index: int = 0
var session: LockstepSession = null
var host_ip_input: LineEdit = null
var status_label: Label = null
var mode_button: Button = null
var mode_caption: Label = null
var map_button: Button = null
var lan_launch_button: Button = null
var _lan_role: String = ""


static func detect_lan_ip() -> String:
	for addr in IP.get_local_addresses():
		var s := String(addr)
		if s.begins_with("192.168.") or s.begins_with("10.") or s.begins_with("172."):
			return s
	return "127.0.0.1"


func selected_mode_key() -> String:
	return String(MODES[mode_index]["key"])


func selected_map_path() -> String:
	return CampaignScreen.MISSION_PATHS[map_index % CampaignScreen.MISSION_PATHS.size()]


func _ready() -> void:
	var tm := ThemeManager.apply_saved()
	settings = ThemeManager.load_settings()
	var pal := tm.palette()
	session = LockstepSession.new()
	add_child(session)
	var col := UiKit.build_screen(self, pal)
	col.add_child(UiKit.button("< BACK", _go_back, settings))
	col.add_child(UiKit.heading("2-PLAYER OPS", pal, 60))
	col.add_child(UiKit.caption("Blind SHA-256 Commit-Reveal planning + 60 Hz deterministic execution.", pal))
	col.add_child(UiKit.heading("MATCH CONFIG", pal, 36))
	mode_button = UiKit.button("", _cycle_mode, settings)
	mode_button.name = "ModeButton"
	mode_button.add_theme_font_size_override("font_size", 24)
	mode_button.clip_text = true
	col.add_child(mode_button)
	mode_caption = UiKit.caption("", pal)
	col.add_child(mode_caption)
	map_button = UiKit.button("", _cycle_map, settings)
	map_button.name = "MapButton"
	map_button.add_theme_font_size_override("font_size", 24)
	map_button.clip_text = true
	col.add_child(map_button)
	col.add_child(UiKit.heading("PASS & PLAY  (1 PHONE)", pal, 36))
	col.add_child(UiKit.caption("P1 plans and locks a salted SHA-256 commitment. Routes hide automatically before handing the phone to P2.", pal))
	var pass_btn := UiKit.button("START PASS & PLAY MATCH", start_pass_and_play, settings)
	pass_btn.name = "StartPassPlayButton"
	col.add_child(pass_btn)
	col.add_child(UiKit.heading("LAN WI-FI LOCKSTEP  (UDP 7600)", pal, 36))
	col.add_child(UiKit.caption("Device LAN IP: %s  ·  Port %d" % [detect_lan_ip(), LockstepSession.PORT], pal, false))
	host_ip_input = LineEdit.new()
	host_ip_input.name = "HostIpInput"
	host_ip_input.text = detect_lan_ip()
	host_ip_input.placeholder_text = "Host IPv4 (e.g. 192.168.1.10)"
	host_ip_input.custom_minimum_size = Vector2(0, 64)
	host_ip_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(host_ip_input)
	var lan_row := HBoxContainer.new()
	lan_row.add_theme_constant_override("separation", 10)
	var host_btn := UiKit.button("HOST LAN", start_lan_host, settings)
	host_btn.name = "HostLanButton"
	host_btn.add_theme_font_size_override("font_size", 24)
	lan_row.add_child(host_btn)
	var join_btn := UiKit.button("JOIN HOST", join_lan_host, settings)
	join_btn.name = "JoinLanButton"
	join_btn.add_theme_font_size_override("font_size", 24)
	lan_row.add_child(join_btn)
	col.add_child(lan_row)
	lan_launch_button = UiKit.button("LAUNCH LAN BOARD", launch_lan_match, settings)
	lan_launch_button.name = "LaunchLanButton"
	lan_launch_button.visible = false
	col.add_child(lan_launch_button)
	status_label = UiKit.caption("Ready. Choose Pass & Play or open a LAN UDP 7600 session.", pal, false)
	status_label.name = "LobbyStatus"
	col.add_child(status_label)
	_refresh_labels()
	print("[TacPlan] screen=two_player modes=%d" % MODES.size())


func _process(_delta: float) -> void:
	if not is_inside_tree():
		return
	if status_label != null and session != null:
		status_label.text = "LAN STATE: " + session.state_text()
	if session == null or not session.session_active:
		return
	if multiplayer == null or multiplayer.multiplayer_peer != session.peer:
		return
	session.poll()
	while not session.received_packets.is_empty():
		var pkt: Dictionary = session.received_packets.pop_front()
		if String(pkt.get("kind", "")) == "match_start":
			var m_path := String(pkt.get("map_path", selected_map_path()))
			var m_mode := String(pkt.get("mode", selected_mode_key()))
			var m_seed := int(pkt.get("seed", 2026))
			var target_ip := host_ip_input.text.strip_edges() if host_ip_input != null else "127.0.0.1"
			session.close_session()
			ScreenRouter.clear_param("mission_loadout")
			ScreenRouter.set_param("map_path", m_path)
			ScreenRouter.set_param("return_stage", int(ScreenRouter.Stage.TWO_PLAYER))
			ScreenRouter.set_param("two_player_config", {
				"transport": "lan",
				"role": "client",
				"host_ip": target_ip,
				"mode": m_mode,
				"seed": m_seed,
			})
			ScreenRouter.goto_stage(ScreenRouter.Stage.IN_MISSION)
			return


func _cycle_mode() -> void:
	mode_index = (mode_index + 1) % MODES.size()
	_refresh_labels()


func _cycle_map() -> void:
	map_index = (map_index + 1) % CampaignScreen.MISSION_PATHS.size()
	_refresh_labels()


func _refresh_labels() -> void:
	var m: Dictionary = MODES[mode_index]
	if mode_button != null:
		mode_button.text = "MODE: " + String(m["label"])
	if mode_caption != null:
		mode_caption.text = String(m["desc"])
	if map_button != null:
		var info := CampaignScreen.describe(selected_map_path())
		map_button.text = "MAP: %s  %s  (%dF)" % [String(info["code"]), String(info["title"]).to_upper(), int(info["floors"])]


func start_pass_and_play() -> void:
	if session != null:
		session.close_session()
	ScreenRouter.clear_param("mission_loadout")
	ScreenRouter.set_param("map_path", selected_map_path())
	ScreenRouter.set_param("return_stage", int(ScreenRouter.Stage.TWO_PLAYER))
	ScreenRouter.set_param("two_player_config", {
		"transport": "pass_play",
		"mode": selected_mode_key(),
		"seed": 2026,
	})
	ScreenRouter.goto_stage(ScreenRouter.Stage.IN_MISSION)


func start_lan_host() -> void:
	if session == null:
		return
	var err: int = session.host_on_port(0, LockstepSession.PORT)
	if err == OK:
		_lan_role = "host"
		if lan_launch_button != null:
			lan_launch_button.visible = true
		if status_label != null:
			status_label.text = "Hosting UDP %d on %s. Have P2 join or tap LAUNCH LAN BOARD." % [LockstepSession.PORT, detect_lan_ip()]
	else:
		if status_label != null:
			status_label.text = "UDP port %d busy (code %d). Use Pass & Play or retry." % [LockstepSession.PORT, err]


func join_lan_host() -> void:
	if session == null:
		return
	var addr := host_ip_input.text.strip_edges() if host_ip_input != null else "127.0.0.1"
	if addr == "":
		addr = "127.0.0.1"
	var err: int = session.connect_on_port(addr, LockstepSession.PORT)
	if err == OK:
		_lan_role = "client"
		if lan_launch_button != null:
			lan_launch_button.visible = true
		if status_label != null:
			status_label.text = "Connecting to %s:%d... waiting for host launch." % [addr, LockstepSession.PORT]
	else:
		if status_label != null:
			status_label.text = "Could not open client socket to %s (code %d)." % [addr, err]


func launch_lan_match() -> void:
	var role := _lan_role if _lan_role != "" else "host"
	var addr := host_ip_input.text.strip_edges() if host_ip_input != null else "127.0.0.1"
	if session != null:
		if role == "host":
			session.send_packet({
				"kind": "match_start",
				"map_path": selected_map_path(),
				"mode": selected_mode_key(),
				"seed": 2026,
			})
		session.close_session()
	ScreenRouter.clear_param("mission_loadout")
	ScreenRouter.set_param("map_path", selected_map_path())
	ScreenRouter.set_param("return_stage", int(ScreenRouter.Stage.TWO_PLAYER))
	ScreenRouter.set_param("two_player_config", {
		"transport": "lan",
		"role": role,
		"host_ip": addr,
		"mode": selected_mode_key(),
		"seed": 2026,
	})
	ScreenRouter.goto_stage(ScreenRouter.Stage.IN_MISSION)


func _go_back() -> void:
	if session != null:
		session.close_session()
	ScreenRouter.goto_stage(ScreenRouter.Stage.TITLE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if UiKit.is_back_event(event):
		_go_back()
