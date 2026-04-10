extends Node

# Runs when the game scene loads in multiplayer mode.
# Reads NetworkManager.players and stamps each player slot with the connected
# player's name. Listens for late-joining players and does the same.

@onready var _table: Table = $"../Table"


func _ready() -> void:
	if not NetworkManager.is_multiplayer:
		return

	# Show names for players already connected when the scene loaded
	for p in NetworkManager.players:
		_set_name_label(p["player_index"], p["name"])

	# Show names for players who join after the scene loaded
	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.player_left.connect(_on_player_left)


func _on_player_joined(peer_id: int, player_name: String, player_index: int) -> void:
	_set_name_label(player_index, player_name)


func _on_player_left(peer_id: int) -> void:
	# Find which slot this peer occupied and clear the label
	for p in NetworkManager.players:
		if p["peer_id"] == peer_id:
			_set_name_label(p["player_index"], "")
			return


func _set_name_label(player_index: int, player_name: String) -> void:
	# players array: indices 0-4 are the non-dealer players, -1 is dealer
	if player_index < 0 or player_index >= _table.players.size() - 1:
		return

	var player: Player = _table.players[player_index]
	var player_ui := player.get_node_or_null("PlayerUI") as Control
	if not player_ui:
		return

	var lbl := player_ui.get_node_or_null("NameLabel") as Label
	if not lbl:
		lbl = Label.new()
		lbl.name = "NameLabel"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.layout_mode = 3       # free positioning inside the Control
		lbl.anchors_preset = Control.PRESET_BOTTOM_WIDE
		lbl.offset_top = 8
		lbl.offset_bottom = 36
		player_ui.add_child(lbl)

	lbl.text = player_name
