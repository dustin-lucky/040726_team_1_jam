class_name CardDef extends Resource

enum Suit { NONE, HEARTS, DIAMONDS, CLUBS, SPADES }
enum Rank { NONE, ACE, TWO, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT, NINE, TEN, JACK, QUEEN, KING }

@export var suit: Suit
@export var rank: Rank
@export var value1: int
@export var value2: int
@export var face: Texture2D
