extends Node

# Hides all player slots on load, then reveals them as players connect.
# Name labels are added below each player's UI panel.

const _NETWORKED_SELECTOR := preload("res://Scripts/Action Selector/action_selector_networked.gd")

@onready var _table: Table = $"../Table"


func _ready() -> void:
	if not NetworkManager.is_multiplayer:
		return

	# Hide every non-dealer slot to start with an empty table
	for i in range(_table.players.size() - 1):
		_table.players[i].visible = false

	# Reveal + label anyone already connected (e.g. host seeing themselves)
	for p in NetworkManager.players:
		_show_player(p["player_index"], p["name"])

	_configure_multiplayer_action_selectors()

	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.player_left.connect(_on_player_left)


func _on_player_joined(_peer_id: int, player_name: String, player_index: int) -> void:
	_show_player(player_index, player_name)
	_swap_selector_to_networked(_table.players[player_index], player_index)


func _on_player_left(_peer_id: int, player_index: int) -> void:
	if player_index >= 0 and player_index < _table.players.size() - 1:
		var pl := _table.players[player_index]
		pl.visible = false
		pl.lives = 0


func _configure_multiplayer_action_selectors() -> void:
	for i in range(_table.players.size() - 1):
		var pl := _table.players[i]
		if NetworkManager.is_table_slot_occupied(i):
			_swap_selector_to_networked(pl, i)
		else:
			pl.lives = 0


func _swap_selector_to_networked(pl: Player, table_index: int) -> void:
	var new_sel: ActionSelector = _NETWORKED_SELECTOR.new() as ActionSelector
	new_sel.name = "ActionSelector_Networked"
	pl.action_selector = new_sel
	pl.action_selector.my_player_index = table_index


func _show_player(player_index: int, player_name: String) -> void:
	if player_index < 0 or player_index >= _table.players.size() - 1:
		return
	var player := _table.players[player_index]
	player.visible = true
	_set_name_label(player, player_name)


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
