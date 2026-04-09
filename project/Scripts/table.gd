class_name Table extends Node2D

@export var deck_prefab: PackedScene
@export var discard_pile: DiscardPile
@export var shoe: Shoe

@export var players: Array[Player]

var decks: Array[Deck]

func _ready() -> void:
	for i in players.size():
		players[i].action_selector.my_player_index = i

func get_dealer() -> Player:
	return players[-1]

func populate_decks() -> void:
	for i: int in GameRules.deck_count:
		var deck: Deck = deck_prefab.instantiate()
		add_child(deck)
		deck.populate()
		
		for card: Card in deck.cards:
			discard_pile.add_card(card)
