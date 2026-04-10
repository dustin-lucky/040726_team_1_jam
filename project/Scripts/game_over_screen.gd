class_name GameOverScreen extends CanvasLayer

@export var winners_label: RichTextLabel
@export var winnings_label: RichTextLabel
@export var play_again_button: Button


func _ready() -> void:
	visible = false
	play_again_button.pressed.connect(_on_play_again_pressed)


func show_game_over(winners: Array[Player], winnings: int) -> void:
	if winners.is_empty():
		winners_label.text = "[center]Game over[/center]"
	elif winners.size() == 1:
		winners_label.text = "[center][b]%s[/b]\nwins![/center]" % winners[0].user_name
	else:
		var lines: Array[String] = []
		for p: Player in winners:
			lines.append("[b]%s[/b]" % p.user_name)
		lines.append("Tie!")
		winners_label.text = "[center]%s[/center]" % "\n".join(lines)
	winnings_label.text = "[center]Takes home [b]$%d[/b][/center]" % winnings
	visible = true


func _on_play_again_pressed() -> void:
	get_tree().reload_current_scene()
