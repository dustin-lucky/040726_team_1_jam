class_name GameStateManager extends Node

signal on_game_over(winners: Array[Player], winnings: int)

var pot: int = 2500

@export var table: Table
@export var game_animator: GameAnimator

func _ready() -> void:
	table.populate_decks()
	game_loop()


func game_loop() -> void:
	await game_animator.shuffle_discard_into_shoe()
	for player: Player in table.players:
		player.lives = GameRules.starting_health
	var last_alive_players: Array[Player] = []
	while get_alive_player_count() > 1:
		last_alive_players.clear()
		for player: Player in table.players:
			if player == table.get_dealer():
				continue
			if player.lives > 0:
				last_alive_players.append(player)
		await game_animator.do_initial_deal()
		
		clear_previous_actions()
		while non_dealer_players_still_in_hand():
			for player in table.players:
				if player == table.get_dealer():
					continue
		
				if !player.is_still_in_hand():
					continue
				player.action_selector.request_make_action(table.players)
				await player.action_selector.action_ready
				await handle_player_action(player)
		
		await table.get_dealer().hand.cards[1].flip()
		table.get_dealer().hand.recalculate_score()
		while table.get_dealer().is_still_in_hand():
			await table.get_dealer().action_selector.request_make_action(table.players)
			await handle_player_action(table.get_dealer())
		
		await deal_round_damage()
		await get_tree().create_timer(2.0).timeout
		await game_animator.clean_up_round()

	var alive_count := get_alive_player_count()
	if alive_count == 1:
		for player: Player in table.players:
			if player == table.get_dealer():
				continue
			if player.lives > 0:
				var winners: Array[Player] = [player]
				on_game_over.emit(winners, pot)
				return
	else:
		on_game_over.emit(last_alive_players, pot / last_alive_players.size())


func get_alive_player_count() -> int:
	var count := 0
	for player in table.players:
		if player == table.get_dealer():
			continue
		if player.lives > 0:
			count += 1
	return count

func non_dealer_players_still_in_hand() -> bool:
	for player in table.players:
		if player == table.get_dealer():
			continue
		if player.is_still_in_hand():
			return true
	return false

func clear_previous_actions() -> void:
	for player in table.players:
		player.last_action_taken = null

func deal_round_damage() -> void:
	var dealer := table.get_dealer()
	if GameRules.is_busted(dealer.hand):
		return

	var dealer_score := dealer.hand.current_score
	var non_dealer_players: Array[Player] = []
	var players_taking_damage: Array[Player] = []
	for player: Player in table.players:
		if player == dealer or player.lives <= 0:
			continue
		non_dealer_players.append(player)
		if GameRules.is_busted(player.hand) or player.hand.current_score < dealer_score:
			players_taking_damage.append(player)
	# Players take damage as part of the animation loop
	await game_animator.animate_deal_round_damage(non_dealer_players, players_taking_damage)

func handle_player_action(player: Player) -> void:
	match player.action_selector.action.chosen_action:
		Hand.Action.HIT:
			await game_animator.deal_card_to_player(player)
		Hand.Action.STAND:
			return
		Hand.Action.STEAL:
			var target_player: Player = player.action_selector.action.payload.get(&"target_player", null)
			if target_player == null: return
			
			if GameRules.is_valid_steal_target_for_player(player, target_player):
				target_player.play_steal()
				await game_animator.animate_steal(player.hand, target_player.hand)
		Hand.Action.GIVE:
			var target_player: Player = player.action_selector.action.payload.get(&"target_player", null)
			if target_player == null: return
			
			if GameRules.is_valid_give_target_for_player(player, target_player):
				await game_animator.animate_give(player.hand, target_player.hand)
				target_player.play_give()
