class_name ActionSelector_Defensive extends ActionSelector

func _on_action_requested(player_states: Array[Player]) -> void:
	var my_player: Player = player_states[my_player_index]
	var my_score: int = my_player.hand.current_score

	await get_tree().create_timer(0.5).timeout

	# If busted, give a card to a random valid target to try to recover.
	if my_score > GameRules.blackjack_score:
		var give_targets: Array[Player] = _get_valid_give_targets(my_player, player_states)
		if give_targets.size() > 0:
			action.chosen_action = Hand.Action.GIVE
			action.payload[&"target_player"] = give_targets.pick_random()
			print("%s chose action: GIVE (busted at %d)" % [my_player.name, my_score])
			action_ready.emit()
			return

	# Steal a card if doing so would bring us closer to 21 without going over.
	var best_steal_target: Player = _find_best_steal_target(my_player, player_states)
	if best_steal_target != null:
		action.chosen_action = Hand.Action.STEAL
		action.payload[&"target_player"] = best_steal_target
		print("%s chose action: STEAL (score %d)" % [my_player.name, my_score])
		action_ready.emit()
		return

	# Only hit below 15 — too risky above that threshold.
	if my_score < 15:
		action.chosen_action = Hand.Action.HIT
		print("%s chose action: HIT (score %d)" % [my_player.name, my_score])
		action_ready.emit()
		return

	# Nothing to steal and safe to lock in — stand.
	action.chosen_action = Hand.Action.STAND
	print("%s chose action: STAND (score %d)" % [my_player.name, my_score])
	action_ready.emit()


## Returns the steal target whose card[0] would most improve our score toward 21,
## or null if no beneficial steal exists.
func _find_best_steal_target(my_player: Player, player_states: Array[Player]) -> Player:
	var best_target: Player = null
	var best_score: int = my_player.hand.current_score

	for target in player_states:
		if !GameRules.is_valid_steal_target_for_player(my_player, target):
			continue

		var steal_index: int = GameRules.get_steal_card_index(target.hand)
		if steal_index == -1:
			continue

		var stolen_card: Card = target.hand.get_card(steal_index)
		var simulated_cards: Array[Card] = my_player.hand.cards.duplicate()
		simulated_cards.append(stolen_card)
		var simulated_score: int = my_player.hand.calculate_score(simulated_cards)

		if simulated_score <= GameRules.blackjack_score and simulated_score > best_score:
			best_score = simulated_score
			best_target = target

	return best_target


## Returns all players that this player can legally give a card to.
func _get_valid_give_targets(my_player: Player, player_states: Array[Player]) -> Array[Player]:
	var targets: Array[Player] = []
	for target in player_states:
		if GameRules.is_valid_give_target_for_player(my_player, target):
			targets.append(target)
	return targets
