class_name Shoe extends Node2D


var cards: Array[Card] = []

func count() -> int:
	return cards.size()

func shuffle() -> void:
	cards.shuffle()

func draw() -> Card:
	return cards.pop_back()

func push_front(card: Card) -> void:
	cards.push_front(card)
	_place_card(card)

func push_back(card: Card) -> void:
	cards.push_back(card)
	_place_card(card)

func _place_card(card: Card) -> void:
	card.global_position = global_position
	card.global_rotation = global_rotation
	card.face_up = false
