extends Node2D

func _ready():
	load_saved_game()
	reset_crystals_session_state()
	restore_killed_enemies()

func load_saved_game():
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager:
		var save_data = save_manager.get_save_data()
		var player = get_tree().get_first_node_in_group("player")
		
		if player:
			# ПРИОРИТЕТ 1: Обычное сохранение у кристалла
			if save_data["player_data"]["position"]["x"] != 0:
				player.global_position = Vector2(
					save_data["player_data"]["position"]["x"],
					save_data["player_data"]["position"]["y"]
				)
				player.health = save_data["player_data"]["health"]
				player.gold = save_data["player_data"]["gold"]
				print("✓ Игрок загружен из сохранения кристалла. Золото: ", player.gold)
			
			# ПРИОРИТЕТ 2: Скрытые точки сохранения (если нет обычного)
			elif not save_data["hidden_save_points"].is_empty():
				var hidden_save = save_manager.get_nearest_hidden_save_point(player.global_position)
				if hidden_save and not hidden_save.is_empty():
					player.global_position = hidden_save["position"]
					player.health = save_data["player_data"]["health"]
					player.gold = save_data["player_data"]["gold"]
					print("✓ Игрок загружен из скрытой точки сохранения")
					print("✓ Скрытая точка: ", hidden_save["id"])
					print("✓ Позиция: ", hidden_save["position"])
			
			# ПРИОРИТЕТ 3: Загружаем способности в любом случае
			load_player_abilities(player, save_data)

func load_player_abilities(player, save_data):
	# Загружаем способность рывка
	if save_data["player_data"]["has_dash_ability"] and player.has_method("load_abilities"):
		player.load_abilities()
		print("✓ Способности загружены: Рывок - ", save_data["player_data"]["has_dash_ability"])

func restore_killed_enemies():
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager:
		save_manager.restore_killed_enemies()

func reset_crystals_session_state():
	var crystals = get_tree().get_nodes_in_group("save_crystals")
	for crystal in crystals:
		if crystal.has_method("set_active_state"):
			crystal.set_active_state()
	print("Кристаллы сброшены для новой сессии")

func _exit_tree():
	# При выходе с уровня сбрасываем кристаллы
	reset_crystals_session_state()
