class_name GameStateManager extends Node

@export var table: Table
@export var game_animator: GameAnimator

func _ready() -> void:
	table.populate_decks()
	game_loop()


func game_loop() -> void:
	await game_animator.shuffle_discard_into_shoe()
	while true:
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
		
		while table.get_dealer().is_still_in_hand():
			await table.get_dealer().action_selector.request_make_action(table.players)
			await handle_player_action(table.get_dealer())
		
		await get_tree().create_timer(2.0).timeout
		await game_animator.clean_up_round()

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
				await game_animator.animate_steal(player.hand, target_player.hand)
		Hand.Action.GIVE:
			var target_player: Player = player.action_selector.action.payload.get(&"target_player", null)
			if target_player == null: return
			
			if GameRules.is_valid_give_target_for_player(player, target_player):
				await game_animator.animate_give(player.hand, target_player.hand)
