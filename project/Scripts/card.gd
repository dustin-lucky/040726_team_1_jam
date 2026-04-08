class_name Card extends Node2D

signal clicked(sender: Card)
signal dropped(sender: Card)

const FLIP_HALF_DURATION: float = 0.1

@export var card_front: Texture2D
@export var card_back: Texture2D
@export var sprite: Sprite2D
@export var area: Area2D

enum InteractionMode { BOTH, CLICK_ONLY, DRAG_ONLY }

var value1_override: int
var value2_override: int

var card_def: CardDef
var interaction_mode: InteractionMode = InteractionMode.BOTH
var _flip_tween: Tween = null
var _rumble_tween: Tween = null
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _did_drag: bool = false
var face_up: bool = false:
	set(value):
		face_up = false if card_def == null else value
		_update_sprite()

func _ready() -> void:
	_update_sprite()
	area.mouse_entered.connect(_on_mouse_enter)
	area.mouse_exited.connect(_on_mouse_exit)
	area.input_event.connect(_on_input_event)

func set_def(def: CardDef) -> void:
	card_def = def
	if card_def == null:
		face_up = false
	else:
		value1_override = card_def.value1
		value2_override = card_def.value2
	_update_sprite()

func flip_immediate() -> void:
	face_up = !face_up


func flip() -> void:
	if _flip_tween != null:
		await _flip_tween.finished
		return

	var original_scale_x := sprite.scale.x
	_flip_tween = create_tween()
	_flip_tween.tween_property(sprite, "scale:x", 0.0, FLIP_HALF_DURATION)
	await _flip_tween.finished
	face_up = !face_up
	_flip_tween = create_tween()
	_flip_tween.tween_property(sprite, "scale:x", original_scale_x, FLIP_HALF_DURATION)
	await _flip_tween.finished
	_flip_tween = null

func _update_sprite() -> void:
	if sprite == null:
		return
	if face_up and card_def != null:
		sprite.texture = card_front
		sprite.region_enabled = true
		sprite.region_rect = card_def.get_region()
	else:
		sprite.texture = card_back
		sprite.region_enabled = false

func set_rumble(is_on: bool) -> void:
	if _rumble_tween != null:
		_rumble_tween.kill()
		_rumble_tween = null
	if is_on:
		_rumble_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		for i in 4:
			_rumble_tween.tween_property(sprite, "position", Vector2(randf_range(-1.2, 1.2), randf_range(-1.2, 1.2)), 0.04)
		_rumble_tween.tween_property(sprite, "position", Vector2.ZERO, 0.04)
	else:
		sprite.position = Vector2.ZERO


func set_interaction_mode(mode: InteractionMode) -> void:
	interaction_mode = mode


func enable_mouse_interaction() -> void:
	area.input_pickable = true


func disable_mouse_interaction() -> void:
	area.input_pickable = false

func _on_mouse_enter() -> void:
	pass

func _on_mouse_exit() -> void:
	pass

func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		global_position = get_global_mouse_position() + _drag_offset
		_did_drag = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
		if _did_drag:
			dropped.emit(self)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if interaction_mode != InteractionMode.CLICK_ONLY:
			_dragging = true
			_drag_offset = global_position - get_global_mouse_position()
		_did_drag = false
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and not _did_drag:
		if interaction_mode != InteractionMode.DRAG_ONLY:
			clicked.emit(self)
