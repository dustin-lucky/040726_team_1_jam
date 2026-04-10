extends Control

const LOBBY_URL = "wss://bj-relay.riktestingstuff.partykit.dev/parties/main/bj-lobby"
# For local dev: "ws://localhost:1999/parties/main/bj-lobby"

const PLAYER_NAMES: Array[String] = [
	"Ace Ventura", "Jack Blackjack", "Count Cardula", "Dealer McDealface",
	"Busted Benny", "Double Down Doug", "Hit Me Harry", "Standing Stan",
	"Shufflin' Shawn", "Card Shark Carl", "Lucky Luke", "Natural Nicole",
	"Soft Seventeen Steve", "Insurance Irving", "Hole Card Harold",
	"High Roller Hank", "Shoe Shuffler Sue", "Split Decision Sam",
	"Bust-or-Bust Bob", "Twenty-One Tina",
]

var _ws := WebSocketPeer.new()
var _connected := false
var _my_peer_id := -1
var _room_code := ""
var _selected_code := ""

@onready var name_input: LineEdit = $CenterContainer/VBoxContainer/NameRow/NameInput
@onready var create_button: Button = $CenterContainer/VBoxContainer/CreateGameButton
@onready var join_button: Button = $CenterContainer/VBoxContainer/JoinGameButton
@onready var games_list: VBoxContainer = $CenterContainer/VBoxContainer/GamesListPanel/ScrollContainer/GamesList
@onready var no_games_label: Label = $CenterContainer/VBoxContainer/GamesListPanel/ScrollContainer/GamesList/NoGamesLabel


func _ready() -> void:
	name_input.text = PLAYER_NAMES[randi() % PLAYER_NAMES.size()]
	join_button.disabled = true  # enabled once a game is selected
	_ws.connect_to_url(LOBBY_URL)


func _process(_delta: float) -> void:
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			while _ws.get_available_packet_count() > 0:
				_handle_message(_ws.get_packet().get_string_from_utf8())
		WebSocketPeer.STATE_CLOSED:
			if _connected:
				_connected = false
				create_button.disabled = true


func _handle_message(text: String) -> void:
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		return
	match data.get("type", ""):
		"joined":
			_my_peer_id = data["peer_id"]
			_connected = true
			create_button.disabled = false
			for game in data.get("games", []):
				_add_game_row(game["code"], game["host_name"], game["player_count"])
		"game_added":
			var g: Dictionary = data["game"]
			_add_game_row(g["code"], g["host_name"], g["player_count"])
		"game_updated":
			var g: Dictionary = data["game"]
			_update_game_row(g["code"], g["host_name"], g["player_count"])
		"remove_game":
			_remove_game_row(data["code"])


func _add_game_row(code: String, host_name: String, player_count: int) -> void:
	var row_name := "game_" + code
	if games_list.find_child(row_name, false, false):
		return

	var btn := Button.new()
	btn.name = row_name
	btn.text = _row_text(host_name, player_count)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_row_selected.bind(code))
	games_list.add_child(btn)

	no_games_label.visible = false

	if _selected_code.is_empty():
		_on_row_selected(code)


func _update_game_row(code: String, host_name: String, player_count: int) -> void:
	var btn := games_list.find_child("game_" + code, false, false) as Button
	if btn:
		btn.text = _row_text(host_name, player_count)


func _remove_game_row(code: String) -> void:
	var row := games_list.find_child("game_" + code, false, false)
	if row:
		row.queue_free()
	if _selected_code == code:
		_selected_code = ""
		join_button.disabled = true
	_refresh_no_games_label.call_deferred()
	_auto_select_first.call_deferred()


func _on_row_selected(code: String) -> void:
	_selected_code = code
	join_button.disabled = false
	for child in games_list.get_children():
		if child is Button:
			child.modulate = Color(1.4, 1.4, 0.6) if child.name == "game_" + code else Color.WHITE


func _refresh_no_games_label() -> void:
	var has_games := false
	for child in games_list.get_children():
		if child.name.begins_with("game_"):
			has_games = true
			break
	no_games_label.visible = not has_games


func _auto_select_first() -> void:
	if not _selected_code.is_empty():
		return
	for child in games_list.get_children():
		if child.name.begins_with("game_"):
			_on_row_selected(child.name.trim_prefix("game_"))
			break


func _row_text(host_name: String, player_count: int) -> String:
	return "%s's Game  ·  %d / 5 players" % [host_name, player_count]


func _on_play_local_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/game_scene.tscn")


func _on_create_game_pressed() -> void:
	var host_name := _get_name()
	_room_code = _generate_code()

	# Register with lobby so others can see the game (best-effort — fine if not yet connected)
	if _connected:
		_ws.send_text(JSON.stringify({
			"type": "register_game",
			"code": _room_code,
			"host_name": host_name,
		}))

	create_button.text = "Game Created!  (code: %s)" % _room_code
	create_button.disabled = true

	# Add a Start Game button below the create button
	var start_btn := Button.new()
	start_btn.name = "StartGameButton"
	start_btn.text = "▶  Start Game"
	start_btn.theme_override_font_sizes["font_size"] = 22
	start_btn.pressed.connect(_on_start_game_pressed)
	var vbox := $CenterContainer/VBoxContainer as VBoxContainer
	vbox.add_child(start_btn)
	vbox.move_child(start_btn, create_button.get_index() + 1)


func _on_start_game_pressed() -> void:
	NetworkManager.setup_host(_room_code, _get_name())
	NetworkManager.game_room_ready.connect(_on_game_room_ready, CONNECT_ONE_SHOT)
	NetworkManager.connect_to_game_room()


func _on_join_game_pressed() -> void:
	if _selected_code.is_empty() or not _connected:
		return
	_ws.send_text(JSON.stringify({
		"type": "join_game",
		"code": _selected_code,
	}))
	NetworkManager.setup_client(_selected_code, _get_name())
	NetworkManager.game_room_ready.connect(_on_game_room_ready, CONNECT_ONE_SHOT)
	NetworkManager.connect_to_game_room()


func _on_game_room_ready() -> void:
	get_tree().change_scene_to_file("res://Scenes/game_scene.tscn")


func _get_name() -> String:
	var n := name_input.text.strip_edges()
	return n if not n.is_empty() else PLAYER_NAMES[randi() % PLAYER_NAMES.size()]


func _generate_code() -> String:
	const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code := ""
	for i in 4:
		code += CHARS[randi() % CHARS.length()]
	return code
