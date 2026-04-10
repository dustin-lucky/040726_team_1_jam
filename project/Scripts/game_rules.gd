# Single source of truth for game rules. Autoload pattern which can be accessed via "GameRules".
extends Node

## The number of decks the game will be played with.
@export var deck_count = 1
@export var blackjack_score: int = 21
@export var blackjack_card_count: int = 2
@export var starting_health: int = 3


func is_busted(hand: Hand) -> bool:
	return hand.current_score > blackjack_score


func is_blackjack(hand: Hand) -> bool:
	return hand.get_card_count() == blackjack_card_count and hand.current_score == blackjack_score


func get_steal_card_index(hand: Hand) -> int:
	if !hand_can_be_stolen_from(hand): return -1
	return 0

func get_give_card_index(hand: Hand) -> int:
	if !hand_can_give(hand): return -1
	return 0

func hand_can_be_stolen_from(hand: Hand) -> bool:
	return hand.cards.size() > 1

func hand_can_give(hand: Hand) -> bool:
	return hand.cards.size() > 1

func is_valid_steal_target_for_player(stealing_player: Player, target_player: Player) -> bool:
	return !target_player.is_dealer() && target_player != stealing_player && \
	hand_can_be_stolen_from(target_player.hand) && (target_player.last_action_taken != null && target_player.last_action_taken.chosen_action != Hand.Action.STAND)

func is_valid_give_target_for_player(giving_player: Player, target_player: Player) -> bool:
	return !target_player.is_dealer() && target_player != giving_player && target_player.is_still_in_hand() && target_player.hand.current_score <= 21
