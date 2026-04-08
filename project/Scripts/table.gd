class_name Table extends Node2D

@export var deck_prefab: PackedScene
@export var discard_pile: DiscardPile
@export var shoe: Shoe
@export var card_mover: CardMover

@export var dealer: Dealer
@export var players: Array[Player]

var decks: Array[Deck]

func _ready() -> void:
	for i: int in GameRules.deck_count:
		var new_deck: Deck = deck_prefab.instantiate()
		decks.push_back(new_deck)
		add_child(new_deck)
		new_deck.populate()
		for card: Card in new_deck.cards:
			card.face_up = false
			card_mover.move_card_instant(card, discard_pile.global_position, discard_pile.global_rotation)
			discard_pile.add_card(card)
	fake_play()

func fake_play() -> void:
	while true:
		await do_fake_round()

func do_fake_round() -> void:
	await shuffle_discard_into_shoe()
	await deal_cards()
	await clean_up_round()


func shuffle_discard_into_shoe() -> void:
	var cards_to_move: Array[Card] = discard_pile.cards.duplicate()
	discard_pile.cards.clear()
	
	if cards_to_move.is_empty():
		shoe.shuffle()
		return
	
	await card_mover.move_many(
		cards_to_move,
		shoe.global_position,
		shoe.global_rotation,
		0.05,
		func(card: Card) -> void: shoe.push_back(card)
	)
	shoe.shuffle()

func clean_up_round() -> void:
	var cards_to_move: Array[Card] = []
	for player: Player in players:
		cards_to_move.append_array(player.hand.clear())
	cards_to_move.append_array(dealer.hand.clear())
	
	await card_mover.move_many(
		cards_to_move,
		discard_pile.global_position,
		discard_pile.global_rotation,
		0.05,
		func(card: Card) -> void:
			card.face_up = false
			discard_pile.add_card(card)
	)

func deal_cards() -> void:
	var deal_order: Array[Player] = players.duplicate()
	deal_order.push_back(dealer)
	
	var num_cards_to_deal: int = 2
	
	for i: int in num_cards_to_deal:
		for player: Player in deal_order:
			var card: Card = shoe.draw()
			await card_mover.move_card(
				card,
				player.hand.global_position,
				player.hand.global_rotation
			)
			player.hand.add_card(card)
	
	for player: Player in deal_order:
		for card: Card in player.hand.cards:
			await card.flip()
