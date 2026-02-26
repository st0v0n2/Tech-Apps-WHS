extends Node

enum GameType { MINES, SLIDE }

var current_game: GameType = GameType.MINES


func change_scene_to_mines() -> void:
	current_game = GameType.MINES
	get_tree().change_scene_to_file("res://scenes/mines/mines_game.tscn")


func change_scene_to_slide() -> void:
	current_game = GameType.SLIDE
	get_tree().change_scene_to_file("res://scenes/slide/slide_game.tscn")


func return_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
