extends Area2D

@onready var anim_sprite = $AnimatedSprite2D
@onready var collision = $CollisionShape2D
@onready var particles = $GPUParticles2D

var player_in_range = false
var is_active = true
var crystal_id = ""
var is_on_cooldown = false

func _ready():
	# Создаем уникальный ID на основе позиции
	crystal_id = "crystal_" + str(int(global_position.x)) + "_" + str(int(global_position.y))
	print("Кристалл создан: ", crystal_id)
	add_to_group("save_crystals")
	
	# Проверяем сохранение
	check_saved_state()
	
	# Подключаем сигналы
	if body_entered.get_connections().is_empty():
		body_entered.connect(_on_body_entered)
	if body_exited.get_connections().is_empty():
		body_exited.connect(_on_body_exited)
	
	set_active_state()

func check_saved_state():
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager:
		# Проверяем, не использован ли уже этот кристалл
		if save_manager.is_crystal_used(crystal_id):
			print("Кристалл уже использован: ", crystal_id)
			set_used_state()
			return

func set_active_state():
	is_active = true
	is_on_cooldown = false
	if anim_sprite:
		anim_sprite.play("idle")
	if particles:
		particles.emitting = true
	print("Кристалл активен: ", crystal_id)

func set_used_state():
	is_active = false
	is_on_cooldown = true
	if anim_sprite:
		anim_sprite.play("used")
	if particles:
		particles.emitting = false
	print("Кристалл в использованном состоянии: ", crystal_id)

func _on_body_entered(body):
	if body.is_in_group("player"):
		if is_on_cooldown:
			print("Кристалл перезаряжается...")
			show_message("Кристалл перезаряжается")
		elif is_active:
			player_in_range = true
			print("Рядом с кристаллом. Нажмите B для сохранения и лечения")
			show_message("Нажмите B для сохранения")

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		hide_message()

func interact():
	if player_in_range and is_active and not is_on_cooldown:
		print("Взаимодействие с кристаллом: ", crystal_id)
		
		# Временно деактивируем
		is_active = false
		is_on_cooldown = true
		
		var save_manager = get_node_or_null("/root/SaveManager")
		if save_manager:
			# Визуальные эффекты
			if anim_sprite:
				anim_sprite.play("active")
			if particles:
				particles.emitting = true
			
			# Сохраняем игру (внутри save_game происходит восстановление здоровья)
			save_manager.save_game(crystal_id, global_position)
			
			# Ждем окончания анимации active
			await get_tree().create_timer(1.0).timeout
			
			# Показываем used анимацию
			if anim_sprite:
				anim_sprite.play("used")
			print("✓ Сохранение и полное восстановление здоровья завершены!")
			
			# Перезарядка 3 секунды
			await get_tree().create_timer(3.0).timeout
			
			# Возвращаем в активное состояние
			set_active_state()
			print("Кристалл снова готов к использованию")
			
		else:
			print("✗ SaveManager не доступен!")
			# Если ошибка, возвращаем активное состояние
			set_active_state()
	else:
		print("Кристалл не готов к взаимодействию")

func show_message(text: String):
	# Здесь можно добавить систему UI сообщений
	# Например, показать текст над кристаллом
	print("Сообщение: ", text)
	
	# Простая реализация текстового сообщения
	var label = Label.new()
	label.name = "InteractionLabel"
	label.text = text
	label.position = Vector2(-50, -60)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_font_size_override("font_size", 16)
	add_child(label)

func hide_message():
	var label = get_node_or_null("InteractionLabel")
	if label:
		label.queue_free()

# Функция для принудительной активации (например, при создании кристалла рывком)
func force_activate():
	set_active_state()
	print("Кристалл принудительно активирован: ", crystal_id)
