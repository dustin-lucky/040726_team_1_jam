class_name DiscardPile extends Node2D

var cards: Array[Card] = []


func add_card(card: Card) -> void:
	cards.append(card)
	card.reparent(self)
	card.face_up = false
