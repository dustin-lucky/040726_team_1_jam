class_name LocalPlayerUI extends CanvasLayer

@export var player: Player
var context: Array[Player]

@export var hit_button: Button
@export var stand_button: Button
@export var steal_button: Button
@export var give_button: Button

@export var player_buttons_root: Control
@export var player_buttons: Array[Button]


func _ready() -> void:
	visible = false
	hit_button.pressed.connect(_hit_selected)
	stand_button.pressed.connect(_stand_selected)
	steal_button.pressed.connect(_steal_selected)
	give_button.pressed.connect(_give_selected)
	for i in range(player_buttons.size()):
		player_buttons[i].pressed.connect(select_player.bind(i))

func show_for_context(local_player: Player, all_players: Array[Player]) -> void:
	player = local_player
	context = all_players
	for i in range(min(player_buttons.size(), all_players.size())):
		player_buttons[i].text = all_players[i].user_name
	visible = true

func hide_away() -> void:
	player = null
	context = []
	hide_player_buttons(true)
	visible = false

func update_player_buttons_for_steal(players: Array[Player]) -> void:
	for i in range(player_buttons.size()):
		var button = player_buttons[i]
		var target = players[i]
		if target == player or target.is_dealer():
			button.visible = false
		elif not GameRules.is_valid_steal_target_for_player(player, target):
			button.visible = true
			button.disabled = true
		else:
			button.visible = true
			button.disabled = false

func update_player_buttons_for_give(players: Array[Player]) -> void:
	for i in range(player_buttons.size()):
		var button = player_buttons[i]
		var target = players[i]
		if target == player or target.is_dealer():
			button.visible = false
		elif not GameRules.is_valid_give_target_for_player(player, target):
			button.visible = true
			button.disabled = true
		else:
			button.visible = true
			button.disabled = false

func _hit_selected() -> void:
	player.action_selector.action.chosen_action = Hand.Action.HIT
	player.action_selector.action_ready.emit()
	hide_away()

func _stand_selected() -> void:
	player.action_selector.action.chosen_action = Hand.Action.STAND
	player.action_selector.action_ready.emit()
	hide_away()

func _steal_selected() -> void:
	player.action_selector.action.chosen_action = Hand.Action.STEAL
	update_player_buttons_for_steal(context)
	show_player_buttons()

func _give_selected() -> void:
	player.action_selector.action.chosen_action = Hand.Action.GIVE
	update_player_buttons_for_give(context)
	show_player_buttons()

func hide_player_buttons(immediate: bool = false):
	if !player_buttons_root.visible: return
	player_buttons_root.visible = false

func show_player_buttons(immediate: bool = false):
	if player_buttons_root.visible: return
	player_buttons_root.visible = true

func select_player(index: int) -> void:
	player.action_selector.action.payload[&"target_player"] = context[index]
	player.action_selector.action_ready.emit()
	hide_away()
