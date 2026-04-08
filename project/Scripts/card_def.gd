class_name CardDef extends Resource

enum Suit { NONE, HEARTS, DIAMONDS, CLUBS, SPADES }
enum Rank { NONE, ACE, TWO, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT, NINE, TEN, JACK, QUEEN, KING }

const SIZE := Vector2(390, 570)

@export var suit: Suit
@export var rank: Rank
@export var value1: int
@export var value2: int

func get_region() -> Rect2:
	return Rect2(Vector2((rank - 1) * SIZE.x, (suit - 1) * SIZE.y), SIZE)
