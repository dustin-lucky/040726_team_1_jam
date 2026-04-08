class_name Player extends Node2D

signal action_requested()

@export var hand: Hand

var requested_action: Hand.Action

func choose_action() -> void:
	if hand.current_score < 17:
		requested_action = Hand.Action.HIT
	else:
		requested_action = Hand.Action.STAND
	action_requested.emit()
