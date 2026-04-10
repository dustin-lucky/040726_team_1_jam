class_name ActionSelector_LocalPlayer extends ActionSelector

func _on_action_requested(player_states: Array[Player]) -> void:
	var my_player: Player = player_states[my_player_index]
	
	LocalUI.show_for_context(my_player, player_states)
