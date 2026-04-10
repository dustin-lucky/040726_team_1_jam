class_name Player extends Node2D

signal action_selector_changing(sender: Player)
signal action_selector_changed(sender: Player)
signal lives_changed(sender: Player, old_value: int, new_value: int)

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

@export var lose_texture: Texture2D
@export var win_texture: Texture2D
@export var steal_texture: Texture2D
@export var give_texture: Texture2D
@export var effect_sprite: Sprite2D

var lives: int: 
	set(new_value):
		if new_value == lives: return
		var old_value: int = lives
		lives = new_value
		lives_changed.emit(self, old_value, new_value)

var last_action_taken: ActionSelector.Action
var user_name: String
var _effect_tween: Tween = null


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
	return !GameRules.is_blackjack(hand) && lives > 0

func play_win() -> void: _play_effect(win_texture)
func play_lose() -> void: _play_effect(lose_texture)
func play_steal() -> void: _play_effect(steal_texture)
func play_give() -> void: _play_effect(give_texture)

func _play_effect(texture: Texture2D) -> void:
	if _effect_tween:
		_effect_tween.kill()
	effect_sprite.texture = texture
	effect_sprite.scale = Vector2.ZERO
	effect_sprite.rotation = randf_range(-0.2, 0.2)
	effect_sprite.visible = true
	_effect_tween = create_tween()
	# Slam in with overshoot
	_effect_tween.tween_property(effect_sprite, "scale", Vector2(0.26, 0.26), 0.08).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	# Settle to final size
	_effect_tween.tween_property(effect_sprite, "scale", Vector2(0.2, 0.2), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Hold
	_effect_tween.tween_interval(0.65)
	# Wind-up then slam out
	_effect_tween.tween_property(effect_sprite, "scale", Vector2(0.22, 0.22), 0.05).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_effect_tween.tween_property(effect_sprite, "scale", Vector2.ZERO, 0.09).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	await _effect_tween.finished
	effect_sprite.visible = false

func _on_action_selector_changing() -> void:
	if action_selector != null:
		action_selector.action_ready.disconnect(_on_action_selected)
		action_selector.queue_free()
	
	action_selector_changing.emit(self)

func _on_actor_selector_changed() -> void:
	if action_selector != null:
		action_selector.action_ready.connect(_on_action_selected)
		if action_selector.get_parent() != self:
			# .new() selectors have no parent — reparent() requires one; add_child is correct.
			if action_selector.get_parent() == null:
				add_child(action_selector)
			else:
				action_selector.reparent(self)
	
	action_selector_changed.emit(self)
