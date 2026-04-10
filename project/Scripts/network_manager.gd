extends Node

const BASE_URL = "wss://bj-relay.riktestingstuff.partykit.dev/parties/main/"
# For local dev swap to: "ws://localhost:1999/parties/main/"

var is_multiplayer: bool = false
var is_host: bool = false
var room_code: String = ""
var my_name: String = ""
var my_peer_id: int = -1

# Synced RNG for identical shuffle/deals across peers (-1 = not set / local game).
var session_seed: int = -1

# Array of {peer_id: int, name: String, player_index: int}
var players: Array[Dictionary] = []

signal player_joined(peer_id: int, player_name: String, player_index: int)
signal player_left(peer_id: int, player_index: int)
signal game_room_ready()
signal game_started()
## from_peer matches PartyKit relay "from" (sender peer id). target_player_index is table index or -1.
signal player_action_received(from_peer: int, player_index: int, action_key: String, target_player_index: int)

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
	session_seed = -1


func setup_client(code: String, client_name: String) -> void:
	is_multiplayer = true
	is_host = false
	room_code = code
	my_name = client_name
	players.clear()
	_ready_emitted = false
	_client_accepts_start_game = false
	_pending_client_start_game = false
	session_seed = -1


func assign_session_seed_for_new_game() -> void:
	session_seed = randi()


func get_my_player_index() -> int:
	if my_peer_id <= 0:
		return -1
	# Prefer roster from "joined" / "player_joined" (handles JSON number quirks and future id schemes).
	for p in players:
		var roster_pid: int = int(p.get("peer_id", -9999))
		if roster_pid == my_peer_id:
			return int(p.get("player_index", -1))
	# Relay should always include us; keep PartyKit fallback (peer id 1..n → seat 0..n-1).
	return my_peer_id - 1


func is_table_slot_occupied(slot_index: int) -> bool:
	if slot_index < 0:
		return false
	for p in players:
		if int(p.get("player_index", -9999)) == slot_index:
			return true
	return false


func multiplayer_connected_human_count() -> int:
	return players.size()


## Serialize current [member ActionSelector.action] and send; relay does not echo back to sender, so we dispatch locally too.
func send_player_action_from_ui(sel: ActionSelector) -> void:
	if not is_multiplayer:
		return
	var action_key := _hand_action_to_key(sel.action.chosen_action)
	var tgt_idx := -1
	var tp: Variant = sel.action.payload.get(&"target_player", null)
	if tp is Player:
		var p := tp as Player
		if p.action_selector != null:
			tgt_idx = p.action_selector.my_player_index
	var idx := sel.my_player_index
	var msg := {"type": "player_action", "player_index": idx, "action": action_key}
	if tgt_idx >= 0:
		msg["target_player_index"] = tgt_idx
	send(msg)
	player_action_received.emit(my_peer_id, idx, action_key, tgt_idx)


func _hand_action_to_key(a: Hand.Action) -> String:
	match a:
		Hand.Action.HIT:
			return "hit"
		Hand.Action.STAND:
			return "stand"
		Hand.Action.STEAL:
			return "steal"
		Hand.Action.GIVE:
			return "give"
		_:
			return "stand"


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
	var msg_type: String = str(data.get("type", ""))
	match msg_type:
		"joined":
			my_peer_id = int(data.get("peer_id", -1))
			players.clear()
			for p in data.get("players", []):
				if not p is Dictionary:
					continue
				var pd: Dictionary = p as Dictionary
				players.append({
					"peer_id": int(pd.get("peer_id", -1)),
					"name": str(pd.get("name", "")),
					"player_index": int(pd.get("player_index", -1)),
				})
			if not _ready_emitted:
				_ready_emitted = true
				game_room_ready.emit()
		"player_joined":
			var entry := {
				"peer_id": int(data.get("peer_id", -1)),
				"name": str(data.get("name", "")),
				"player_index": int(data.get("player_index", -1)),
			}
			players.append(entry)
			player_joined.emit(entry["peer_id"], entry["name"], entry["player_index"])
		"peer_left":
			var pid := int(data.get("peer_id", -1))
			var left_index := -1
			for p in players:
				if int(p.get("peer_id", -9999)) == pid:
					left_index = int(p.get("player_index", -1))
					break
			players = players.filter(func(p: Dictionary) -> bool: return int(p.get("peer_id", -9999)) != pid)
			player_left.emit(pid, left_index)
		"start_game":
			if data.has("rng_seed"):
				session_seed = int(data.get("rng_seed", -1))
			# Host never receives their own relayed start_game; ignore if we did.
			if is_host:
				return
			if not _client_accepts_start_game:
				_pending_client_start_game = true
				return
			game_started.emit()
		"player_action":
			var from_peer := int(data.get("from", -1))
			var p_idx := int(data.get("player_index", -1))
			var act := str(data.get("action", "stand"))
			var tgt := int(data.get("target_player_index", -1))
			player_action_received.emit(from_peer, p_idx, act, tgt)


func get_player_name(player_index: int) -> String:
	for p in players:
		if int(p.get("player_index", -9999)) == player_index:
			return str(p.get("name", ""))
	return ""
