class_name CardMover extends Node

class RefInt extends RefCounted:
	var value: int

class MoveCompleted extends RefCounted:
	signal finished

@export var move_duration: float = 0.3

var _tweens: Dictionary[Card, Tween] = {}


func move_card_instant(card: Card, target_pos: Vector2, target_rot: float) -> void:
	card.global_position = target_pos
	card.global_rotation = target_rot


func move_card(card: Card, target_pos: Vector2, target_rot: float, duration: float = -1) -> void:
	if duration <= 0:
		duration = move_duration

	if _tweens.has(card):
		_tweens[card].kill()
		_tweens.erase(card)

	var tween := create_tween().set_parallel(true)
	_tweens[card] = tween
	tween.tween_property(card, "global_position", target_pos, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card, "global_rotation", target_rot, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	_tweens.erase(card)


func move_many(cards: Array[Card], target_pos: Vector2, target_rot: float, interval: float, on_card_moved: Callable, duration: float = -1) -> void:
	if duration <= 0:
		duration = move_duration

	var total := cards.size()
	var arrived := RefInt.new()
	var completion := MoveCompleted.new()

	for i in total:
		var card := cards[i]
		get_tree().create_timer(i * interval).timeout.connect(func() -> void:
			await move_card(card, target_pos, target_rot, duration)
			on_card_moved.call(card)
			arrived.value += 1
			if arrived.value == total:
				completion.finished.emit()
		)

	await completion.finished
