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

## Animates [param giver]'s rightmost card moving to [param receiver]'s hand.
func animate_give(giver: Hand, receiver: Hand) -> void:
	if giver.cards.is_empty():
		return
	
	var card_index: int = GameRules.get_give_card_index(giver)
	if card_index < 0: 
		return
	
	var card: Card = giver.cards[card_index]
	giver.remove_card(card)
	
	await card_mover.move_card(card, receiver.global_position, receiver.global_rotation)
	receiver.add_card(card)

## Smoothly rotates the dealer's hand to face [param target_hand].
func animate_dealer_look_at(target_hand: Hand) -> void:
	var dealer_hand: Hand = table.get_dealer().hand
	var direction: Vector2 = target_hand.global_position - dealer_hand.global_position
	var tween := create_tween()
	tween.tween_property(dealer_hand, "rotation", direction.angle() - PI / 2.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished

## Punches the dealer's hand toward [param target_hand], then returns it to its original position.
func animate_dealer_punch(target_hand: Hand, on_punch: Callable) -> void:
	var dealer_hand: Hand = table.get_dealer().hand
	var original_position: Vector2 = dealer_hand.global_position
	var punch_position: Vector2 = original_position.lerp(target_hand.global_position, 0.4)
	var tween := create_tween()
	tween.tween_property(dealer_hand, "global_position", punch_position, 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)
	await tween.finished
	on_punch.call()
	tween = create_tween()
	tween.tween_property(dealer_hand, "global_position", original_position, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished

## Animates the dealer comparing hands and punching players who are taking damage.
## [param non_dealer_players] is the full list to compare; [param players_taking_damage] is the subset that loses a life.
func animate_deal_round_damage(non_dealer_players: Array[Player], players_taking_damage: Array[Player]) -> void:
	var dealer_hand: Hand = table.get_dealer().hand
	var original_rotation: float = dealer_hand.rotation

	for player: Player in non_dealer_players:
		await animate_dealer_look_at(player.hand)
		if player in players_taking_damage:
			await get_tree().create_timer(0.3).timeout
			await animate_dealer_punch(player.hand, func() -> void: player.lives -= 1)
		else:
			await get_tree().create_timer(0.5).timeout

	var tween := create_tween()
	tween.tween_property(dealer_hand, "rotation", original_rotation, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished

## Animates [param stealer] taking [param target]'s leftmost card into their own hand.
func animate_steal(stealer: Hand, target: Hand) -> void:
	if target.cards.is_empty():
		return
	
	var card_index: int = GameRules.get_steal_card_index(target)
	if card_index < 0: 
		return
	
	var card: Card = target.cards[card_index]
	target.remove_card(card)
	
	await card_mover.move_card(card, stealer.global_position, stealer.global_rotation)
	stealer.add_card(card)
