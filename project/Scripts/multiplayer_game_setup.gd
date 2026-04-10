extends Node

# Hides all player slots on load, then reveals them as players connect.
# Name labels are added below each player's UI panel.

@onready var _table: Table = $"../Table"


func _ready() -> void:
	if not NetworkManager.is_multiplayer:
		return

	if NetworkManager.is_host:
		_add_host_admit_lobby_button()

	# Hide every non-dealer slot to start with an empty table
	for i in range(_table.players.size() - 1):
		_table.players[i].visible = false

	# Reveal + label anyone already connected (e.g. host seeing themselves)
	for p in NetworkManager.players:
		_show_player(p["player_index"], p["name"])

	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.player_left.connect(_on_player_left)


func _on_player_joined(_peer_id: int, player_name: String, player_index: int) -> void:
	_show_player(player_index, player_name)


func _on_player_left(_peer_id: int, player_index: int) -> void:
	if player_index >= 0 and player_index < _table.players.size() - 1:
		_table.players[player_index].visible = false


func _show_player(player_index: int, player_name: String) -> void:
	if player_index < 0 or player_index >= _table.players.size() - 1:
		return
	var player := _table.players[player_index]
	player.visible = true
	_set_name_label(player, player_name)


func _add_host_admit_lobby_button() -> void:
	# Late joiners wait in lobby until they receive start_game; host already sent once
	# before entering — use this to relay start_game again when new players are waiting.
	var layer := CanvasLayer.new()
	layer.name = "HostAdmitLobbyLayer"
	var btn := Button.new()
	btn.text = "Admit waiting lobby players"
	btn.position = Vector2(16, 16)
	btn.pressed.connect(func() -> void:
		NetworkManager.send({"type": "start_game"})
	)
	layer.add_child(btn)
	add_child(layer)


func _set_name_label(player: Player, player_name: String) -> void:
	# Add label as a sibling of PlayerUI, positioned just below it
	var lbl := player.get_node_or_null("NameLabel") as Label
	if not lbl:
		lbl = Label.new()
		lbl.name = "NameLabel"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.layout_mode = 3          # free position inside the Node2D parent
		lbl.offset_left   = -70.0
		lbl.offset_right  =  70.0
		lbl.offset_top    =  108.0   # just below PlayerUI which ends at ~104
		lbl.offset_bottom =  134.0
		player.add_child(lbl)
	lbl.text = player_name
