class_name Player extends Node2D

@export var hand: Hand
@export var action_selector: ActionSelector

var last_action_taken: ActionSelector.Action

func _ready() -> void:
	action_selector.action_ready.connect(_on_action_selected)

func _on_action_selected() -> void:
	last_action_taken = action_selector.action

func is_still_in_hand() -> bool:
	if last_action_taken != null && last_action_taken.chosen_action == ActionSelector.ActionTypes.STAND:
		return false
	return !GameRules.is_blackjack(hand) && !GameRules.is_busted(hand)
