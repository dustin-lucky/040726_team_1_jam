class_name Player extends Node2D

signal action_selector_changing(sender: Player)
signal action_selector_changed(sender: Player)

static var _name_pool: Array[String] = [
	"Ace McGee", "Busted Bart", "Lucky Lou", "Double Down Dana",
	"Shufflin' Sam", "Card Shark Carla", "High Roller Hank", "Split Pete",
	"Dealer's Bane", "Soft Seventeen Sue", "Blackjack Betty", "Bust-Out Bob",
	"Counting Carl", "Insurance Ivan", "Hit Me Harry", "Stand Pat Patty",
	"Risky Rita", "Natural Nina", "Shoe Shaker Shawn", "All-In Al"
]

@export var hand: Hand
@export var action_selector: ActionSelector:
	set(new_value):
		if action_selector == new_value: return
		_on_action_selector_changing()
		action_selector = new_value
		_on_actor_selector_changed()

var last_action_taken: ActionSelector.Action
var user_name: String

func _ready() -> void:
	if _name_pool.size() > 0:
		var idx := randi() % _name_pool.size()
		user_name = _name_pool[idx]
		_name_pool.remove_at(idx)

func is_dealer() -> bool: return false

func _on_action_selected() -> void:
	last_action_taken = action_selector.action

func is_still_in_hand() -> bool:
	if last_action_taken != null && last_action_taken.chosen_action == Hand.Action.STAND:
		return false
	return !GameRules.is_blackjack(hand) && !GameRules.is_busted(hand)

func _on_action_selector_changing() -> void:
	if action_selector != null:
		action_selector.action_ready.disconnect(_on_action_selected)
		action_selector.queue_free()
	
	action_selector_changing.emit(self)

func _on_actor_selector_changed() -> void:
	if action_selector != null:
		action_selector.action_ready.connect(_on_action_selected)
		if action_selector.get_parent() != self:
			action_selector.reparent(self)
	
	action_selector_changed.emit(self)
