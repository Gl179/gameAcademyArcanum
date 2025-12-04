extends Area2D

@onready var anim = $AnimatedSprite2D
@onready var collision_shape = get_node_or_null("CollisionShape2D")

var player_in_range: bool = false
var can_interact: bool = true
var is_open: bool = false
var target_scene: String = "res://level_2.tscn"
var is_entrance_door: bool = false

# Для хранения временных элементов
var interaction_hint: Label = null
var lock_effect: Sprite2D = null
var boss_check_timer: Timer = null

func _ready() -> void:
	# Отладочная информация
	print("=== ДВЕРЬ ИНИЦИАЛИЗАЦИЯ ===")
	print("Имя: ", name)
	print("Тип: Area2D")
	print("Позиция: ", global_position)
	
	# Проверяем структуру сцены
	print("\nДочерние узлы:")
	for child in get_children():
		print("  - ", child.name, " (", child.get_class(), ")")
	
	# ПОДКЛЮЧАЕМ СИГНАЛЫ ВРУЧНУЮ!
	print("\nПодключение сигналов Area2D...")
	connect_signals()
	
	# Проверяем наличие коллизии
	if collision_shape:
		print("✓ CollisionShape2D найден")
	else:
		print("✗ CollisionShape2D не найден! Проверьте структуру сцены")
		# Создаем CollisionShape2D если его нет
		create_collision_shape()
	
	# Проверяем наличие анимации
	if anim:
		print("✓ AnimatedSprite2D найден")
		# В Godot 4 проверяем наличие анимации через sprite_frames
		if anim.sprite_frames:
			if anim.sprite_frames.has_animation("idle"):
				anim.play("idle")
				print("✓ Анимация 'idle' запущена")
			else:
				print("✗ Анимация 'idle' не найдена в sprite_frames")
		else:
			print("✗ SpriteFrames не настроены у AnimatedSprite2D")
	else:
		print("✗ AnimatedSprite2D не найден")
		simple_door_setup()
	
	# Определяем тип двери
	if "entrance" in name.to_lower() or position.x < 100:
		is_entrance_door = true
		target_scene = "res://level.tscn"
		print("✓ Это входная дверь (на уровень 1)")
	else:
		print("✓ Это выходная дверь (на уровень 2)")
	
	# Проверяем босса если это выходная дверь
	if not is_entrance_door:
		print("\nПроверка статуса босса...")
		check_boss_status()
	else:
		print("\nВходная дверь - всегда доступна")
		can_interact = true
	
	print("can_interact: ", can_interact)
	print("player_in_range: ", player_in_range)
	print("=== ИНИЦИАЛИЗАЦИЯ ЗАВЕРШЕНА ===\n")
	
	# Проверяем, есть ли игрок в зоне сразу после загрузки
	check_initial_overlap()

func connect_signals():
	# Подключаем сигналы в коде, если они не подключены в редакторе
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
		print("✓ Сигнал body_entered подключен")
	else:
		print("✓ Сигнал body_entered уже подключен")
	
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
		print("✓ Сигнал body_exited подключен")
	else:
		print("✓ Сигнал body_exited уже подключен")

func check_initial_overlap():
	# Проверяем, есть ли игрок в зоне при запуске
	var overlapping_bodies = get_overlapping_bodies()
	print("\nПроверка начального перекрытия...")
	print("Найдено тел в зоне: ", overlapping_bodies.size())
	
	for body in overlapping_bodies:
		print("Тело: ", body.name, " (", body.get_class(), ")")
		if body.is_in_group("player"):
			print("✓ Игрок уже в зоне при запуске!")
			player_in_range = true
			print("player_in_range установлено в true")

func create_collision_shape():
	print("Создаю CollisionShape2D...")
	var new_collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(40, 80)  # Размер двери
	new_collision.shape = shape
	add_child(new_collision)
	collision_shape = new_collision
	print("✓ CollisionShape2D создан")

func check_boss_status():
	var bosses = get_tree().get_nodes_in_group("boss")
	print("Найдено боссов в группе 'boss': ", bosses.size())
	
	if bosses.size() > 0:
		var boss = bosses[0]
		print("Босс найден: ", boss.name)
		
		# Проверяем состояние босса
		var boss_alive = true
		
		if boss.has_method("is_alive"):
			boss_alive = boss.is_alive()
		elif boss.has_method("take_damage"):
			# Безопасный доступ к свойствам
			var alive_value = boss.get("alive")
			if alive_value != null:
				boss_alive = alive_value
			else:
				var health_value = boss.get("health")
				if health_value != null:
					boss_alive = health_value > 0
		
		if boss_alive:
			print("✓ Босс жив - дверь заблокирована")
			can_interact = false
			show_lock_effect()
			start_boss_check_timer(boss)
		else:
			print("✓ Босс уже мертв - дверь доступна")
			can_interact = true
	else:
		print("✓ Боссов не найдено - дверь доступна")
		can_interact = true

func start_boss_check_timer(boss):
	boss_check_timer = Timer.new()
	add_child(boss_check_timer)
	boss_check_timer.wait_time = 0.5
	boss_check_timer.timeout.connect(_on_boss_check_timer_timeout.bind(boss))
	boss_check_timer.start()
	print("Таймер проверки босса запущен (0.5 сек)")

func _on_boss_check_timer_timeout(boss: Node):
	var is_boss_alive = true
	
	if boss.has_method("is_alive"):
		is_boss_alive = boss.is_alive()
	elif boss.has_method("take_damage"):
		var alive_value = boss.get("alive")
		if alive_value != null:
			is_boss_alive = alive_value
		else:
			var health_value = boss.get("health")
			if health_value != null:
				is_boss_alive = health_value > 0
	
	if not is_boss_alive:
		print("✓ Босс побежден! Разблокируем дверь")
		unlock_door()
		if boss_check_timer:
			boss_check_timer.stop()
			boss_check_timer.queue_free()
			boss_check_timer = null

func show_lock_effect():
	print("Дверь заблокирована - показываем эффект")
	
	if anim:
		anim.modulate = Color(0.3, 0.3, 0.3, 0.8)
	
	lock_effect = Sprite2D.new()
	lock_effect.name = "LockEffect"
	
	# Создаем красный круг
	var image = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	for x in range(24):
		for y in range(24):
			var distance = Vector2(x - 12, y - 12).length()
			if distance < 10 and distance > 8:
				image.set_pixel(x, y, Color.RED)
	
	var texture = ImageTexture.create_from_image(image)
	lock_effect.texture = texture
	lock_effect.position = Vector2(0, -35)
	add_child(lock_effect)

func remove_lock_effect():
	if lock_effect:
		lock_effect.queue_free()
		lock_effect = null

func unlock_door():
	if can_interact:
		return
	
	print("\n=== РАЗБЛОКИРОВКА ДВЕРИ ===")
	can_interact = true
	
	if anim:
		anim.modulate = Color(1, 1, 1, 1)
		print("Цвет восстановлен")
	
	remove_lock_effect()
	
	show_unlock_message()
	print("=== ДВЕРЬ РАЗБЛОКИРОВАНА ===\n")

func show_unlock_message():
	var label = Label.new()
	label.name = "UnlockMessage"
	label.text = "ДОСТУПНО!"
	label.position = Vector2(-35, -70)
	label.modulate = Color(0, 1, 0, 1)
	add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 2.0)
	tween.tween_callback(label.queue_free)

func _process(delta: float) -> void:
	# Обработка ввода только если игрок рядом
	if player_in_range and can_interact and not is_open:
		# Показываем подсказку
		if not interaction_hint or not is_instance_valid(interaction_hint):
			show_interaction_hint()
		
		# Проверяем кнопку ВВЕРХ
		if Input.is_action_just_pressed("ui_up"):
			print("\n=== ОТКРЫТИЕ ДВЕРИ ===")
			print("Кнопка ВВЕРХ нажата")
			print("Состояние двери:")
			print("  player_in_range: ", player_in_range)
			print("  can_interact: ", can_interact)
			print("  is_open: ", is_open)
			open_door()
	else:
		# Убираем подсказку если игрок ушел
		if interaction_hint and is_instance_valid(interaction_hint):
			interaction_hint.queue_free()
			interaction_hint = null

func show_interaction_hint():
	if interaction_hint and is_instance_valid(interaction_hint):
		return
	
	interaction_hint = Label.new()
	interaction_hint.name = "InteractionHint"
	interaction_hint.text = "[ВВЕРХ]"
	interaction_hint.position = Vector2(-25, -50)
	interaction_hint.modulate = Color(1, 1, 0.8, 1)
	add_child(interaction_hint)
	print("Подсказка показана: [ВВЕРХ]")

func open_door():
	if is_open or not can_interact:
		print("Дверь не может быть открыта")
		return
	
	is_open = true
	print("Дверь открывается...")
	
	# Убираем подсказку
	if interaction_hint and is_instance_valid(interaction_hint):
		interaction_hint.queue_free()
		interaction_hint = null
	
	# Анимация открытия
	if anim and anim.sprite_frames:
		if anim.sprite_frames.has_animation("open"):
			print("Проигрываем анимацию 'open'")
			anim.play("open")
			await anim.animation_finished
			print("Анимация завершена")
		else:
			print("Анимации 'open' нет")
			await get_tree().create_timer(0.5).timeout
	else:
		print("Анимации нет, ждем 0.5 сек")
		await get_tree().create_timer(0.5).timeout
	
	# Переход на другой уровень
	fade_and_transition()

func fade_and_transition():
	print("Затемнение экрана и переход...")
	
	# Создаем overlay для затемнения
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "FadeCanvas"
	canvas_layer.layer = 999
	
	var overlay = ColorRect.new()
	overlay.name = "FadeOverlay"
	overlay.color = Color(0, 0, 0, 0)
	overlay.size = get_viewport().size
	
	canvas_layer.add_child(overlay)
	get_tree().root.add_child(canvas_layer)
	
	# Плавное затемнение
	var tween = create_tween()
	tween.tween_property(overlay, "color:a", 1.0, 1.0)
	await tween.finished
	
	print("Переход на сцену: ", target_scene)
	
	save_progress()
	
	# Переход
	get_tree().change_scene_to_file(target_scene)

func save_progress():
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var gold = 0
			if player.has_method("get_gold"):
				gold = player.get_gold()
			elif "gold" in player:
				gold = player.gold
			
			save_manager.save_player_progress(
				player.global_position,
				player.health,
				gold
			)
			print("Прогресс сохранен")

# === СИГНАЛЫ AREA2D ===
func _on_body_entered(body: Node2D) -> void:
	print("\n=== ТЕЛО ВОШЛО В ЗОНУ ДВЕРИ ===")
	print("Тело: ", body.name, " (", body.get_class(), ")")
	print("Группы тела:")
	for group in body.get_groups():
		print("  - ", group)
	
	if body.is_in_group("player"):
		print("✓ Это игрок!")
		player_in_range = true
		
		# Показываем статус двери
		if not can_interact:
			print("Дверь заблокирована")
			show_blocked_message()
		else:
			print("Дверь доступна")
	else:
		print("✗ Это не игрок")
	
	print("player_in_range: ", player_in_range)
	print("=============================\n")

func show_blocked_message():
	var label = Label.new()
	label.name = "BlockedMessage"
	label.text = "УБЕЙТЕ БОССА!"
	label.position = Vector2(-40, -80)
	label.modulate = Color(1, 0.3, 0.3, 1)
	add_child(label)
	
	await get_tree().create_timer(2.0).timeout
	label.queue_free()

func _on_body_exited(body: Node2D) -> void:
	print("\n=== ТЕЛО ВЫШЛО ИЗ ЗОНЫ ДВЕРИ ===")
	print("Тело: ", body.name)
	
	if body.is_in_group("player"):
		print("✓ Игрок ушел")
		player_in_range = false
		print("player_in_range: ", player_in_range)
		
		# Убираем подсказку
		if interaction_hint and is_instance_valid(interaction_hint):
			interaction_hint.queue_free()
			interaction_hint = null
			print("Подсказка убрана")
	
	print("==============================\n")

# Функции для отладки
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		print("\n[DEBUG] Кнопка ВВЕРХ нажата")
		print("Состояние двери:")
		print("  player_in_range: ", player_in_range)
		print("  can_interact: ", can_interact)
		print("  is_open: ", is_open)
		print("  is_entrance_door: ", is_entrance_door)
		
		# Проверяем всех игроков рядом
		var bodies = get_overlapping_bodies()
		print("Тела в зоне: ", bodies.size())
		for body in bodies:
			print("  - ", body.name, " (", body.get_class(), ")")
		
		# ВАЖНО: Если сигналы не работают, обновляем player_in_range вручную!
		for body in bodies:
			if body.is_in_group("player"):
				print("Обнаружен игрок в зоне, обновляем player_in_range")
				player_in_range = true
				break
		
		if player_in_range and can_interact and not is_open:
			print("✓ Все условия выполнены, открываем дверь!")
			open_door()
		else:
			print("✗ Условия не выполнены:")
			if not player_in_range: print("  - Игрок не в зоне")
			if not can_interact: print("  - Дверь заблокирована")
			if is_open: print("  - Дверь уже открыта")

# Простой вариант если не работает AnimatedSprite2D
func simple_door_setup():
	print("\n=== ПРОСТАЯ НАСТРОЙКА ДВЕРИ ===")
	
	if not anim:
		print("Создаю простой спрайт для двери...")
		var sprite = Sprite2D.new()
		sprite.name = "DoorSprite"
		
		var door_texture = load("res://assets/door.png")
		if door_texture:
			sprite.texture = door_texture
		else:
			var image = Image.create(32, 64, false, Image.FORMAT_RGBA8)
			image.fill(Color(0.6, 0.4, 0.2))
			for x in range(32):
				for y in range(64):
					if x == 0 or x == 31 or y == 0 or y == 63:
						image.set_pixel(x, y, Color(0.4, 0.2, 0.1))
			
			var texture = ImageTexture.create_from_image(image)
			sprite.texture = texture
		
		add_child(sprite)
		print("✓ Спрайт двери создан")
	
	print("=== НАСТРОЙКА ЗАВЕРШЕНА ===")

# Альтернативный способ: обновление состояния каждый кадр
func check_player_in_range_every_frame():
	# Этот метод можно вызвать из _process если сигналы не работают
	var overlapping_bodies = get_overlapping_bodies()
	var player_found = false
	
	for body in overlapping_bodies:
		if body.is_in_group("player"):
			player_found = true
			break
	
	if player_found and not player_in_range:
		print("Игрок обнаружен в зоне (каждый кадр)")
		player_in_range = true
	elif not player_found and player_in_range:
		print("Игрок покинул зону (каждый кадр)")
		player_in_range = false
