extends Control


func _on_play_local_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/game_scene.tscn")
