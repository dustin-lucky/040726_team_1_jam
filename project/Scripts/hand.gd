class_name Hand extends Node2D

signal card_added(sender: Hand, card: Card, new_score: int)
signal current_score_changed(sender: Hand, new_score: int)

enum Action {
	NONE = 0,
	HIT = 1,
	STAND = 2,
	STEAL = 4,
	GIVE = 8
}

var id: int
var current_score: int:
	set(value):
		current_score = value
		current_score_changed.emit(self, value)

var cards: Array[Card] = []
var available_actions: Action = Action.NONE
@export var card_offset_x: int = 40



@warning_ignore("shadowed_variable_base_class")
func add_card(card: Card, rotation_degrees: float = 0.0) -> void:
	cards.append(card)
	card.z_index = cards.size() - 1
	card.reparent(self)
	card.rotation = deg_to_rad(rotation_degrees)
	reposition_cards()
	recalculate_score()
	available_actions = get_available_actions()
	card_added.emit(self, card, current_score)


func recalculate_score() -> void:
	current_score = calculate_score(cards)


func get_card_count() -> int:
	return cards.size()


func get_card(index: int) -> Card:
	return cards[index]


func remove_card(card: Card) -> void:
	card.z_index = 0
	card.set_rumble(false)
	cards.erase(card)
	recalculate_score()
	available_actions = get_available_actions()
	reposition_cards()


func clear() -> Array[Card]:
	var cleared: Array[Card] = cards.duplicate()
	for card in cleared:
		remove_card(card)
	return cleared


func get_available_action_count() -> int:
	var count := 0
	for action in [Action.HIT, Action.STAND, Action.STEAL, Action.GIVE]:
		if available_actions & action:
			count += 1
	return count


func get_available_actions() -> Action:
	if GameRules.is_blackjack(self):
		return Action.STAND
	
	var actions := Action.STAND | Action.STEAL
	
	if current_score < GameRules.blackjack_score:
		actions |= Action.HIT
	
	if GameRules.hand_can_give(self):
		actions |= Action.GIVE
	
	return actions as Action


func reposition_cards() -> void:
	var total_width := (cards.size() - 1) * card_offset_x
	for i in cards.size():
		cards[i].position.x = i * card_offset_x - total_width / 2.0


func calculate_score(hand_cards: Array[Card], only_face_up_cards: bool = true) -> int:
	var options: Array = []
	for card in hand_cards:
		if not card.face_up and only_face_up_cards:
			options.append([0])
		elif card.value1_override != card.value2_override:
			options.append([card.value1_override, card.value2_override])
		else:
			options.append([card.value1_override])
	return _best_score(options, 0, 0)


func _best_score(options: Array, index: int, current_sum: int) -> int:
	if index == options.size():
		return current_sum
	var best := -1
	for value in options[index]:
		var candidate := _best_score(options, index + 1, current_sum + value)
		if best == -1:
			best = candidate
		elif candidate <= GameRules.blackjack_score and (best > GameRules.blackjack_score or candidate > best):
			best = candidate
		elif candidate > GameRules.blackjack_score and best > GameRules.blackjack_score and candidate < best:
			best = candidate
	return best
