class_name ActionSelector_Networked extends ActionSelector

var _bound_net: Callable = Callable()
var _listening: bool = false
## Latest table.players passed to request_make_action (signal + .bind() arg order is unreliable).
var _player_states_for_net: Array[Player] = []


func _on_action_requested(player_states: Array[Player]) -> void:
	action = Action.new()
	if _listening and NetworkManager.player_action_received.is_connected(_bound_net):
		NetworkManager.player_action_received.disconnect(_bound_net)
	_player_states_for_net = player_states
	# Callable must match signal (from_peer, player_index, action_key, target_player_index) — no bind().
	_bound_net = Callable(self, "_on_net_player_action")
	NetworkManager.player_action_received.connect(_bound_net)
	_listening = true
	if my_player_index == NetworkManager.get_my_player_index():
		if my_player_index < 0 or my_player_index >= player_states.size():
			push_error("ActionSelector_Networked: invalid my_player_index %d" % my_player_index)
			return
		var me: Player = player_states[my_player_index]
		LocalUI.show_for_context(me, player_states)


func _on_net_player_action(from_peer: int, p_idx: int, action_key: String, target_idx: int) -> void:
	var player_states: Array[Player] = _player_states_for_net
	if p_idx != my_player_index:
		return
	if _listening and NetworkManager.player_action_received.is_connected(_bound_net):
		NetworkManager.player_action_received.disconnect(_bound_net)
		_listening = false
	if my_player_index == NetworkManager.get_my_player_index():
		LocalUI.hide_away()
	_apply_action_key(player_states, action_key, target_idx)
	action_ready.emit()


func _apply_action_key(player_states: Array[Player], action_key: String, target_idx: int) -> void:
	match action_key:
		"hit":
			action.chosen_action = Hand.Action.HIT
		"stand":
			action.chosen_action = Hand.Action.STAND
		"steal":
			action.chosen_action = Hand.Action.STEAL
			if target_idx >= 0 and target_idx < player_states.size():
				action.payload[&"target_player"] = player_states[target_idx]
		"give":
			action.chosen_action = Hand.Action.GIVE
			if target_idx >= 0 and target_idx < player_states.size():
				action.payload[&"target_player"] = player_states[target_idx]
		_:
			action.chosen_action = Hand.Action.STAND
