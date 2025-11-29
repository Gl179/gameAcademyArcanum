extends Node

const SAVE_FILE_PATH = "user://game_save.dat"

var save_data = {
	"player_data": {
		"gold": 0,
		"health": 100,
		"position": {"x": 0, "y": 0},
		"current_level": "",
		"has_dash_ability": false
	},
	"used_crystals": [],
	"killed_enemies": [],
	"collected_dash_crystals": [],
	"hidden_save_points": {}
}

func _ready():
	print("SaveManager загружен!")
	load_game()
	
	# Отладочная информация о сохранениях
	print("=== ИНФО О СОХРАНЕНИИ ===")
	print("Обычное сохранение: ", save_data["player_data"]["position"]["x"] != 0)
	print("Скрытых точек: ", save_data["hidden_save_points"].size())
	print("Есть рывок: ", save_data["player_data"]["has_dash_ability"])
	print("========================")

# Сохранение у кристалла
func save_game(crystal_id: String, crystal_position: Vector2):
	print("Начинаем сохранение...")
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# ПОЛНОЕ ВОССТАНОВЛЕНИЕ ЗДОРОВЬЯ
		var health_before = player.health
		player.health = 100
		var health_restored = player.health - health_before
		
		# Визуальный эффект лечения
		if health_restored > 0 and player.has_method("show_heal_effect"):
			player.show_heal_effect()
		
		# Сохраняем данные игрока
		save_data["player_data"]["gold"] = player.gold
		save_data["player_data"]["health"] = player.health
		save_data["player_data"]["position"] = {
			"x": crystal_position.x,
			"y": crystal_position.y
		}
		save_data["player_data"]["current_level"] = get_tree().current_scene.scene_file_path
		
		# Добавляем кристалл в использованные
		if not crystal_id in save_data["used_crystals"]:
			save_data["used_crystals"].append(crystal_id)
		
		# Сохраняем убитых врагов
		save_killed_enemies()
		
		# Сохраняем в файл
		save_to_file()
		
		print("✓ Игра сохранена! Кристалл: ", crystal_id)
		if health_restored > 0:
			print("✓ Полное восстановление здоровья! +", health_restored, " HP")
		else:
			print("✓ Здоровье уже было полным")
	else:
		print("✗ Игрок не найден!")

# Загрузка игры
func load_game():
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var test_json_conv = JSON.new()
		test_json_conv.parse(json_string)
		var loaded_data = test_json_conv.get_data()
		
		if loaded_data:
			save_data = loaded_data
			print("✓ Игра загружена из файла")
		else:
			print("✗ Ошибка загрузки сохранения")
		file.close()
	else:
		print("ℹ️ Сохранение не найдено, используется новое")

# Сохранение в файл
func save_to_file():
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_data)
		file.store_string(json_string)
		file.close()
		print("✓ Файл сохранения обновлен")
		print_save_data()
	else:
		print("✗ Ошибка создания файла сохранения")

# Проверка кристалла
func is_crystal_used(crystal_id: String) -> bool:
	return crystal_id in save_data["used_crystals"]

# Управление кристаллами рывка
func add_collected_dash_crystal(crystal_id: String):
	if not crystal_id in save_data["collected_dash_crystals"]:
		save_data["collected_dash_crystals"].append(crystal_id)
		save_data["player_data"]["has_dash_ability"] = true
		save_to_file()
		print("✓ Кристалл рывка добавлен в сохранение: ", crystal_id)

func is_dash_crystal_collected(crystal_id: String) -> bool:
	return crystal_id in save_data["collected_dash_crystals"]

# Скрытые точки сохранения (для способностей)
func create_hidden_save_point(save_id: String, position: Vector2):
	save_data["hidden_save_points"][save_id] = {
		"position": {"x": position.x, "y": position.y},
		"level": get_tree().current_scene.scene_file_path
	}
	save_to_file()
	print("Скрытая точка сохранения создана: ", save_id)

# Получение ближайшей скрытой точки сохранения
func get_nearest_hidden_save_point(player_position: Vector2) -> Dictionary:
	var nearest_save = {}
	var min_distance = INF
	
	for save_id in save_data["hidden_save_points"]:
		var save_data_point = save_data["hidden_save_points"][save_id]
		var save_position = Vector2(save_data_point["position"]["x"], save_data_point["position"]["y"])
		var distance = player_position.distance_to(save_position)
		
		if distance < min_distance:
			min_distance = distance
			nearest_save = {
				"id": save_id,
				"position": save_position,
				"level": save_data_point["level"]
			}
	
	return nearest_save

# Получение данных
func get_save_data():
	return save_data

func get_player_abilities():
	return {
		"has_dash_ability": save_data["player_data"]["has_dash_ability"]
	}

# Сброс сохранения для новой игры
func reset_save():
	save_data = {
		"player_data": {
			"gold": 0,
			"health": 100,
			"position": {"x": 0, "y": 0},
			"current_level": "",
			"has_dash_ability": false
		},
		"used_crystals": [],
		"killed_enemies": [],
		"collected_dash_crystals": [],
		"hidden_save_points": {}
	}
	save_to_file()
	print("✓ Сохранение сброшено для новой игры")

# Сохранение убитых врагов
func save_killed_enemies():
	# Очищаем старый список
	save_data["killed_enemies"] = []
	
	# Находим всех врагов которые должны быть мертвы
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_method("is_alive") and not enemy.is_alive():
			# Сохраняем ID мертвого врага
			var enemy_id = "enemy_" + str(int(enemy.global_position.x)) + "_" + str(int(enemy.global_position.y))
			save_data["killed_enemies"].append(enemy_id)
	
	print("Сохранено убитых врагов: ", save_data["killed_enemies"].size())

# Восстановление убитых врагов при загрузке
func restore_killed_enemies():
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		var enemy_id = "enemy_" + str(int(enemy.global_position.x)) + "_" + str(int(enemy.global_position.y))
		if enemy_id in save_data["killed_enemies"]:
			if enemy.has_method("queue_free"):
				enemy.queue_free()
				print("Враг удален по сохранению: ", enemy_id)

# Отладочная информация
func print_save_data():
	print("=== СОХРАНЕНИЕ ===")
	print("Золото: ", save_data["player_data"]["gold"])
	print("Здоровье: ", save_data["player_data"]["health"])
	print("Позиция: ", save_data["player_data"]["position"])
	print("Уровень: ", save_data["player_data"]["current_level"])
	print("Рывок: ", save_data["player_data"]["has_dash_ability"])
	print("Кристаллы: ", save_data["used_crystals"])
	print("Кристаллы рывка: ", save_data["collected_dash_crystals"])
	print("Скрытые точки: ", save_data["hidden_save_points"])
	print("Убитые враги: ", save_data["killed_enemies"])
	print("==================")
