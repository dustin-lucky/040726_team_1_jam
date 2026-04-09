class_name ActionSelector_Dealer extends ActionSelector

func _on_action_requested(player_states: Array[Player]) -> void:
	var my_player: Player = player_states[my_player_index]
	
	if my_player.hand.current_score >= 17:
		action.chosen_action = ActionTypes.STAND
	else:
		action.chosen_action = ActionTypes.HIT
		await get_tree().create_timer(1.0).timeout
	
	print("%s chose action: %s" % [my_player.name, action.chosen_action])
	action_ready.emit()
