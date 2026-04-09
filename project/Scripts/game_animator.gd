class_name GameAnimator extends Node

@export var table: Table
@export var card_mover: CardMover

## Shuffles all discarded cards back into the shoe.
func shuffle_discard_into_shoe() -> void:
	var cards_to_move: Array[Card] = table.discard_pile.cards.duplicate()
	table.discard_pile.cards.clear()
	
	if cards_to_move.is_empty():
		table.shoe.shuffle()
		return
	
	await card_mover.move_many(
		cards_to_move,
		table.shoe.global_position,
		table.shoe.global_rotation,
		0.05,
		func(card: Card) -> void: table.shoe.push_back(card)
	)
	table.shoe.shuffle()

## Moves all in play cards to the discard pile.
func clean_up_round() -> void:
	var cards_to_move: Array[Card] = []
	for player: Player in table.players:
		cards_to_move.append_array(player.hand.clear())
	
	await card_mover.move_many(
		cards_to_move,
		table.discard_pile.global_position,
		table.discard_pile.global_rotation,
		0.05,
		func(card: Card) -> void:
			card.face_up = false
			table.discard_pile.add_card(card)
	)

## Deals one card to each player and the dealer in sequence, then again.
## The dealer's second card will be face down.
func do_initial_deal() -> void:
	var deal_order: Array[Player] = table.players.duplicate()
	
	var num_cards_to_deal: int = 2
	
	for i: int in num_cards_to_deal:
		for player: Player in deal_order:
			var face_up: bool = false
			if player != table.get_dealer() || i == 0:
				face_up = true
			await deal_card_to_player(player, face_up)

## Deal a single card to [param player], adding it to their hand upon arrival.
func deal_card_to_player(player: Player, face_up = true) -> void:
	if table.shoe.count() <= 0:
		await shuffle_discard_into_shoe()
	
	var card: Card = table.shoe.draw()
	card.face_up = face_up
	
	await card_mover.move_card(card, player.hand.global_position, player.hand.global_rotation)
	player.hand.add_card(card)
