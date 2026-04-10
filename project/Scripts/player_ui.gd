class_name PlayerUI extends Control

@export var player: Player

@export var action_label: RichTextLabel
@export var score_label: RichTextLabel

func _ready() -> void:
	player.action_selector_changing.connect(_on_player_action_selector_changing)
	player.action_selector_changed.connect(_on_player_action_selector_changed)
	player.hand.current_score_changed.connect(_on_hand_score_changed)
	if player.action_selector != null:
		_on_player_action_selector_changed(player)


func _on_hand_score_changed(_sender: Hand, new_score: int) -> void:
	score_label.text = str(new_score)

func _on_action_selected() -> void:
	action_label.text = str(player.action_selector.action.chosen_action)

func _on_player_action_selector_changing(_sender: Player) -> void:
	if player.action_selector != null:
		player.action_selector.action_ready.disconnect(_on_action_selected)

func _on_player_action_selector_changed(_sender: Player) -> void:
	if player.action_selector != null:
		player.action_selector.action_ready.connect(_on_action_selected)
