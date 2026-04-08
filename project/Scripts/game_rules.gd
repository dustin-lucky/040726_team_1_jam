# Single source of truth for game rules. Autoload pattern which can be accessed via "GameRules".
extends Node

## The number of decks the game will be played with.
@export var deck_count = 1
@export var blackjack_score: int = 21
@export var blackjack_card_count: int = 2
@export var player_damage_multiplier: float = 1.0
@export var splits_allowed: bool = false


func is_busted(hand: Hand) -> bool:
	return hand.current_score > blackjack_score


func is_blackjack(hand: Hand) -> bool:
	return hand.get_card_count() == blackjack_card_count and hand.current_score == blackjack_score
