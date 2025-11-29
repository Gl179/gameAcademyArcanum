extends Node2D

func _ready():
	print("Меню загружено")
	setup_save_manager()

func setup_save_manager():
	if not has_node("/root/SaveManager"):
		var save_manager = preload("res://save_manager.gd").new()
		get_tree().root.add_child(save_manager)
		save_manager.name = "SaveManager"
		print("✓ SaveManager создан в меню")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_continue_pressed() -> void:
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager:
		var save_data = save_manager.get_save_data()
		
		# ПРОВЕРЯЕМ ЕСТЬ ЛИ ЛЮБОЕ СОХРАНЕНИЕ (обычное или скрытое)
		var has_any_save = (
			save_data["player_data"]["position"]["x"] != 0 or 
			not save_data["hidden_save_points"].is_empty()
		)
		
		if has_any_save and save_data["player_data"]["current_level"] != "":
			get_tree().change_scene_to_file(save_data["player_data"]["current_level"])
			print("Загружаем сохраненную игру")
			print("Есть скрытых точек сохранения: ", save_data["hidden_save_points"].size())
		else:
			print("Нет сохраненной игры")
			show_no_save_message()
	else:
		print("SaveManager не доступен")

func _on_new_game_pressed() -> void:
	# Сбрасываем сохранение
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager:
		save_manager.reset_save()
	
	# Загружаем уровень
	get_tree().change_scene_to_file("res://level.tscn")
	print("Начинаем новую игру")

func show_no_save_message():
	# Можно добавить UI сообщение "Нет сохраненной игры"
	print("Нет сохраненной игры для загрузки")
