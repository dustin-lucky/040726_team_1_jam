## Handles choosing player actions.
@abstract class_name ActionSelector extends Node

enum ActionTypes {
	STAND,
	HIT
}

class Action extends RefCounted:
	var chosen_action: ActionTypes = ActionTypes.STAND
	var payload: Dictionary[StringName, Variant] = {}

@warning_ignore("unused_signal")
signal action_ready
var action: Action:
	set(new_value):
		if new_value == null: new_value = Action.new()
		action = new_value

var my_player_index: int = -1

func request_make_action(player_states: Array[Player]) -> void:
	action = Action.new()
	await get_tree().create_timer(0.1).timeout
	_on_action_requested(player_states)

## Populate [member action] and raise [signal action_ready].
@abstract func _on_action_requested(player_states: Array[Player]) -> void
