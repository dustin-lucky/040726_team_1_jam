class_name Deck extends Node2D

const CARD_SCENE: PackedScene = preload("uid://buhrdy6mf82wf")

const CARD_WIDTH: float = 54.0
const CARD_HEIGHT: float = 82.0

@export var card_defs: Array[CardDef] = []

var cards: Array[Card] = []

func populate() -> void:
	for def in card_defs:
		var card := CARD_SCENE.instantiate() as Card
		add_child(card)
		card.global_position = global_position
		card.set_def(def)
		card.face_up = false
		cards.append(card)

func debug_layout() -> void:
	const COLS: int = 13
	const PAD_X: float = 4.0
	const PAD_Y: float = 4.0
	for i in cards.size():
		var col: int = i % COLS
		@warning_ignore("integer_division")
		var row: int = i / COLS
		cards[i].global_position = global_position + Vector2(
			col * (CARD_WIDTH + PAD_X),
			row * (CARD_HEIGHT + PAD_Y)
		)
		cards[i].face_up = true
