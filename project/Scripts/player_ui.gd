class_name PlayerUI extends Control

@export var player: Player

@export var score_label: RichTextLabel
@export var name_label: RichTextLabel

func _ready() -> void:
	player.action_selector_changing.connect(_on_player_action_selector_changing)
	player.action_selector_changed.connect(_on_player_action_selector_changed)
	player.hand.current_score_changed.connect(_on_hand_score_changed)
	
	if player.action_selector != null:
		_on_player_action_selector_changed(player)
	
	call_deferred("update_name")

func update_name() -> void:
	if name_label != null:
		name_label.text = player.user_name

func _on_hand_score_changed(_sender: Hand, new_score: int) -> void:
	score_label.text = str(new_score)

func _on_player_action_selector_changing(_sender: Player) -> void:
	pass

func _on_player_action_selector_changed(_sender: Player) -> void:
	pass
