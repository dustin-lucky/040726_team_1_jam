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

@onready var name_input: LineEdit = $CenterContainer/VBoxContainer/NameRow/NameInput
@onready var create_button: Button = $CenterContainer/VBoxContainer/CreateGameButton
@onready var games_list: VBoxContainer = $CenterContainer/VBoxContainer/GamesListPanel/ScrollContainer/GamesList
@onready var no_games_label: Label = $CenterContainer/VBoxContainer/GamesListPanel/ScrollContainer/GamesList/NoGamesLabel


func _ready() -> void:
	name_input.text = PLAYER_NAMES[randi() % PLAYER_NAMES.size()]
	create_button.disabled = true  # enabled once WS connects
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
		"remove_game":
			_remove_game_row(data["code"])


func _add_game_row(code: String, host_name: String, player_count: int) -> void:
	var row_name := "game_" + code
	if games_list.find_child(row_name, false, false):
		return  # already listed

	var row := HBoxContainer.new()
	row.name = row_name

	var lbl := Label.new()
	lbl.text = "%s's Game  ·  %d / 5 players" % [host_name, player_count]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	games_list.add_child(row)
	no_games_label.visible = false


func _remove_game_row(code: String) -> void:
	var row := games_list.find_child("game_" + code, false, false)
	if row:
		row.queue_free()
	# Check next frame whether any game rows remain
	_refresh_no_games_label.call_deferred()


func _refresh_no_games_label() -> void:
	var has_games := false
	for child in games_list.get_children():
		if child.name.begins_with("game_"):
			has_games = true
			break
	no_games_label.visible = not has_games


func _on_play_local_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/game_scene.tscn")


func _on_create_game_pressed() -> void:
	if not _connected:
		return
	var host_name := name_input.text.strip_edges()
	if host_name.is_empty():
		host_name = PLAYER_NAMES[randi() % PLAYER_NAMES.size()]

	_room_code = _generate_code()
	_ws.send_text(JSON.stringify({
		"type": "register_game",
		"code": _room_code,
		"host_name": host_name,
	}))

	create_button.text = "Game Created!  (code: %s)" % _room_code
	create_button.disabled = true


func _generate_code() -> String:
	const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code := ""
	for i in 4:
		code += CHARS[randi() % CHARS.length()]
	return code
