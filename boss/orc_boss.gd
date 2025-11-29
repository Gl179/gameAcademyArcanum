extends CharacterBody2D

@onready var anim = $AnimatedSprite2D

# Характеристики босса
var speed = 70
var health = 100
var max_health = 100
var chase = false
var alive = true
var is_attacking: bool = false
var is_taking_damage: bool = false
var damage_timer: float = 0.0
const DAMAGE_ANIMATION_DURATION = 0.3
var player_node: Node2D = null

# Таймеры и кулдауны
var attack_cooldown: float = 0.0
const ATTACK_COOLDOWN_TIME: float = 2.0

# Визуальные эффекты
var health_bar: ColorRect
var health_bar_bg: ColorRect

const GRAVITY = 980.0

func _ready() -> void:
	# Добавляем во все возможные группы
	add_to_group("enemies")
	add_to_group("enemy") 
	add_to_group("boss")
	add_to_group("damageable")
	
	# Создаем визуальные элементы
	create_health_bar()
	
	print("=== БОСС ЗАГРУЖЕН ===")
	print("Здоровье: ", health)
	
	find_player()

func create_health_bar():
	# ПРОСТОЙ ВАРИАНТ - создаем как дочерние элементы
	# Создаем фон полоски здоровья
	health_bar_bg = ColorRect.new()
	health_bar_bg.name = "HealthBarBG"
	health_bar_bg.size = Vector2(204, 24)  # Увеличил высоту для лучшей видимости
	health_bar_bg.color = Color(0, 0, 0)  # Черный фон
	health_bar_bg.position = Vector2(-102, -180)  # Выше над головой
	add_child(health_bar_bg)
	
	# Создаем основную полоску здоровья
	health_bar = ColorRect.new()
	health_bar.name = "HealthBar"
	health_bar.size = Vector2(200, 20)
	health_bar.color = Color(0, 1, 0)  # Зеленый
	health_bar.position = Vector2(-100, -178)
	add_child(health_bar)
	
	print("Полоска здоровья создана")

func update_health_bar():
	if health_bar:
		var health_ratio = float(health) / float(max_health)
		health_bar.size.x = 200 * health_ratio
		
		# Меняем цвет в зависимости от здоровья
		if health_ratio > 0.6:
			health_bar.color = Color(0, 1, 0)  # Зеленый
		elif health_ratio > 0.3:
			health_bar.color = Color(1, 1, 0)  # Желтый
		else:
			health_bar.color = Color(1, 0, 0)  # Красный
		
		print("Обновлена полоска здоровья: ", health_ratio * 100, "%")

func show_attack_effect():
	# Подсветка при атаке
	modulate = Color(1.5, 0.8, 0.8)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.3)

func show_damage_effect():
	# Эффект получения урона
	modulate = Color(2, 0.5, 0.5)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.2)

func find_player():
	player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		print("Игрок найден")

func _physics_process(delta: float) -> void:
	if not alive:
		return
	
	# Обновление таймеров
	if is_taking_damage:
		damage_timer -= delta
		if damage_timer <= 0:
			is_taking_damage = false
	
	if attack_cooldown > 0:
		attack_cooldown -= delta
	
	# Гравитация
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	
	# Основная логика ИИ
	if chase and alive and not is_attacking and not is_taking_damage:
		handle_chasing_state()
	else:
		velocity.x = 0
		if not is_attacking and not is_taking_damage:
			anim.play("Idle")
	
	move_and_slide()

func handle_chasing_state():
	if not player_node:
		find_player()
		if not player_node:
			return
	
	var direction = (player_node.position - position).normalized()
	var distance = position.distance_to(player_node.position)
	
	# Движение к игроку
	velocity.x = direction.x * speed
	
	# Поворот
	anim.flip_h = direction.x < 0
	
	anim.play("walk")
	
	# Атака при близкой дистанции
	if distance < 100 and attack_cooldown <= 0:
		start_attack()

func start_attack():
	if is_attacking:
		return
	
	print("Босс атакует!")
	is_attacking = true
	velocity.x = 0
	
	# Эффект атаки
	show_attack_effect()
	
	anim.play("Attak")
	
	# Ждем перед нанесением урона
	await get_tree().create_timer(0.4).timeout
	
	# Наносим урон если игрок рядом
	if alive and player_node and position.distance_to(player_node.position) < 120:
		print("Босс попадает по игроку!")
		if player_node.has_method("take_damage"):
			player_node.take_damage(30)
	
	await get_tree().create_timer(0.3).timeout
	
	# Завершаем атаку
	if alive:
		is_attacking = false
		attack_cooldown = ATTACK_COOLDOWN_TIME

func take_damage(damage_amount: int) -> void:
	if not alive or is_taking_damage:
		return
	
	print("Босс получает урон: ", damage_amount)
	
	# Уменьшаем урон для босса
	var reduced_damage = int(damage_amount * 0.3)
	if reduced_damage < 1:
		reduced_damage = 1
	
	health -= reduced_damage
	update_health_bar()  # ВАЖНО: обновляем полоску при получении урона
	
	is_taking_damage = true
	damage_timer = DAMAGE_ANIMATION_DURATION
	
	# Визуальный эффект получения урона
	show_damage_effect()
	
	# Прерываем атаку
	if is_attacking:
		is_attacking = false
	
	anim.play("hurt")
	velocity.x = 0
	
	# Слабый отбрасывание
	if player_node:
		var knockback_dir = (position - player_node.position).normalized()
		velocity = knockback_dir * 50
		velocity.y = -30
	
	print("Здоровье босса: ", health, "/", max_health)
	
	if health <= 0:
		death()

func _on_detector_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and alive:
		print("Игрок обнаружен!")
		player_node = body
		chase = true
		
func _on_detector_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("Игрок потерян")
		chase = false

func death():
	print("=== БОСС ПОБЕЖДЕН! ===")
	alive = false
	velocity = Vector2.ZERO
	
	# Скрываем полоску здоровья
	if health_bar:
		health_bar.visible = false
	if health_bar_bg:
		health_bar_bg.visible = false
	
	# Отключаем коллизии
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true
	if has_node("detector/CollisionShape2D"):
		$detector/CollisionShape2D.disabled = true
	
	anim.play("death")
	
	# Награда
	spawn_rewards()
	
	await get_tree().create_timer(2.0).timeout
	queue_free()

func spawn_rewards():
	# Золото
	var gold_coin_scene = preload("res://collectibles/gold.tscn")
	for i in range(10):
		var coin = gold_coin_scene.instantiate()
		get_parent().add_child(coin)
		var offset = Vector2(randf_range(-60, 60), randf_range(-40, -80))
		coin.position = position + offset
		if coin.has_method("apply_impulse"):
			var impulse = Vector2(randf_range(-80, 80), randf_range(-120, -180))
			coin.apply_impulse(impulse)
	
	print("Босс оставил награду!")
