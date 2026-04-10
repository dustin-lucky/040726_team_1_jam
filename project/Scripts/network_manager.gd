extends Node

const BASE_URL = "wss://bj-relay.riktestingstuff.partykit.dev/parties/main/"
# For local dev swap to: "ws://localhost:1999/parties/main/"

var is_multiplayer: bool = false
var is_host: bool = false
var room_code: String = ""
var my_name: String = ""
var my_peer_id: int = -1

# Array of {peer_id: int, name: String, player_index: int}
var players: Array[Dictionary] = []

signal player_joined(peer_id: int, player_name: String, player_index: int)
signal player_left(peer_id: int, player_index: int)
signal game_room_ready()
signal game_started()

var _ws := WebSocketPeer.new()
var _ready_emitted := false

# Joiners only react to start_game after lobby shows "waiting" (avoids same-packet
# joined + start_game skipping the wait UI; also buffers until host starts later).
var _client_accepts_start_game: bool = false
var _pending_client_start_game: bool = false


func setup_host(code: String, host_name: String) -> void:
	is_multiplayer = true
	is_host = true
	room_code = code
	my_name = host_name
	players.clear()
	_ready_emitted = false
	_client_accepts_start_game = false
	_pending_client_start_game = false


func setup_client(code: String, client_name: String) -> void:
	is_multiplayer = true
	is_host = false
	room_code = code
	my_name = client_name
	players.clear()
	_ready_emitted = false
	_client_accepts_start_game = false
	_pending_client_start_game = false


func mark_client_ready_to_receive_start_game() -> void:
	if not is_multiplayer or is_host:
		return
	_client_accepts_start_game = true
	if _pending_client_start_game:
		_pending_client_start_game = false
		game_started.emit()


func connect_to_game_room() -> void:
	_ws = WebSocketPeer.new()  # fresh socket each time
	var url := BASE_URL + "bj-" + room_code + "?name=" + my_name.replace(" ", "%20")
	_ws.connect_to_url(url)


func send(msg: Dictionary) -> void:
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(msg))


func _process(_delta: float) -> void:
	if not is_multiplayer:
		return
	_ws.poll()
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		while _ws.get_available_packet_count() > 0:
			_handle_message(_ws.get_packet().get_string_from_utf8())


func _handle_message(text: String) -> void:
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		return
	match data.get("type", ""):
		"joined":
			my_peer_id = int(data["peer_id"])
			players.clear()
			for p in data.get("players", []):
				players.append({
					"peer_id": int(p["peer_id"]),
					"name": str(p["name"]),
					"player_index": int(p["player_index"]),
				})
			if not _ready_emitted:
				_ready_emitted = true
				game_room_ready.emit()
		"player_joined":
			var entry := {
				"peer_id": int(data["peer_id"]),
				"name": str(data["name"]),
				"player_index": int(data["player_index"]),
			}
			players.append(entry)
			player_joined.emit(entry["peer_id"], entry["name"], entry["player_index"])
		"peer_left":
			var pid := int(data["peer_id"])
			var left_index := -1
			for p in players:
				if p["peer_id"] == pid:
					left_index = p["player_index"]
					break
			players = players.filter(func(p: Dictionary) -> bool: return p["peer_id"] != pid)
			player_left.emit(pid, left_index)
		"start_game":
			# Host never receives their own relayed start_game; ignore if we did.
			if is_host:
				return
			if not _client_accepts_start_game:
				_pending_client_start_game = true
				return
			game_started.emit()


func get_player_name(player_index: int) -> String:
	for p in players:
		if p["player_index"] == player_index:
			return p["name"]
	return ""
