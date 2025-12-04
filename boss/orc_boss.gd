extends CharacterBody2D

@onready var anim = $AnimatedSprite2D

# Характеристики босса
signal boss_defeated
var speed = 120
var health = 500
var max_health = 500
var chase = false
var alive = true
var is_attacking: bool = false
var is_taking_damage: bool = false
var damage_timer: float = 0.0
const DAMAGE_ANIMATION_DURATION = 0.3
var player_node: Node2D = null

# Таймеры и кулдауны
var attack_cooldown: float = 0.0
var attack_cooldown_time: float = 1.5
var jump_cooldown: float = 0.0
const JUMP_COOLDOWN_TIME: float = 2.0
var move_timer: float = 0.0
const MOVE_CHANGE_TIME: float = 1.5

# Урон от касания
var touch_damage: int = 10
var touch_cooldown: float = 0.0
const TOUCH_COOLDOWN_TIME: float = 1.0

# Параметры прыжка
var is_jumping: bool = false
var jump_velocity: float = -350.0
var jump_gravity: float = 980.0

const GRAVITY = 980.0

func _ready() -> void:
	# Добавляем во все возможные группы
	add_to_group("enemies")
	add_to_group("enemy") 
	add_to_group("boss")
	add_to_group("damageable")
	
	print("=== БОСС ЗАГРУЖЕН ===")
	print("Здоровье: ", health)
	
	find_player()
	
	# Начинаем с случайного движения
	move_timer = MOVE_CHANGE_TIME

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
	
	if jump_cooldown > 0:
		jump_cooldown -= delta
	
	if touch_cooldown > 0:
		touch_cooldown -= delta
	
	# Таймер смены направления движения
	move_timer -= delta
	if move_timer <= 0:
		move_timer = MOVE_CHANGE_TIME
	
	# Обработка прыжка
	if is_jumping:
		velocity.y += jump_gravity * delta
		if is_on_floor():
			is_jumping = false
	
	# Гравитация для обычного состояния
	if not is_on_floor() and not is_jumping:
		velocity.y += GRAVITY * delta
	
	# Основная логика ИИ - всегда активен!
	if alive and not is_attacking and not is_taking_damage and not is_jumping:
		handle_ai_state(delta)
	
	move_and_slide()

func handle_ai_state(delta: float):
	if not player_node:
		find_player()
		if not player_node:
			return
	
	var direction = (player_node.position - position).normalized()
	var distance = position.distance_to(player_node.position)
	
	# Поворот в сторону игрока
	anim.flip_h = direction.x < 0
	
	# АКТИВНОЕ ПОВЕДЕНИЕ: всегда двигается или атакует
	if chase:
		# Преследование игрока
		handle_chasing_state(distance, direction)
	else:
		# Патрулирование/активное движение по арене
		handle_patrol_state()
	
	# Частые прыжки по арене
	if jump_cooldown <= 0 and randf() < 0.3:
		start_arena_jump()
	
	# Атака при близкой дистанции
	if distance < 80 and attack_cooldown <= 0:
		start_attack()

func handle_chasing_state(distance: float, direction: Vector2):
	# Движение к игроку
	velocity.x = direction.x * speed
	anim.play("walk")
	
	# Иногда меняем направление для большей активности
	if move_timer <= 0:
		velocity.x *= -1

func handle_patrol_state():
	# Активное движение по арене когда игрок далеко
	if move_timer <= 0:
		# Случайное направление
		velocity.x = [-speed, speed][randi() % 2]
	else:
		# Продолжаем движение в текущем направлении
		velocity.x = velocity.x if velocity.x != 0 else speed
	
	anim.play("walk")
	
	# Если уперлись в стену - прыгаем
	if is_on_wall():
		start_arena_jump()

func start_arena_jump():
	if is_jumping or jump_cooldown > 0:
		return
	
	print("Босс прыгает по арене!")
	is_jumping = true
	jump_cooldown = JUMP_COOLDOWN_TIME
	
	# Прыжок в случайном направлении
	var jump_direction = Vector2.LEFT if randf() < 0.5 else Vector2.RIGHT
	velocity = jump_direction * speed * 0.8
	velocity.y = jump_velocity
	
	anim.play("Jump")

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
	await get_tree().create_timer(0.3).timeout
	
	# Наносим урон если игрок рядом
	if alive and player_node and position.distance_to(player_node.position) < 100:
		print("Босс попадает по игроку!")
		if player_node.has_method("take_damage"):
			player_node.take_damage(25)
	
	await get_tree().create_timer(0.3).timeout
	
	# Завершаем атаку
	if alive:
		is_attacking = false
		attack_cooldown = attack_cooldown_time
		start_arena_jump()

func take_damage(damage_amount: int) -> void:
	if not alive or is_taking_damage:
		return
	
	print("Босс получает урон: ", damage_amount)
	
	var reduced_damage = int(damage_amount * 0.5)
	if reduced_damage < 1:
		reduced_damage = 1
	
	health -= reduced_damage
	
	is_taking_damage = true
	damage_timer = DAMAGE_ANIMATION_DURATION
	
	show_damage_effect()
	
	if is_attacking:
		is_attacking = false
	
	anim.play("hurt")
	velocity.x = 0
	
	if player_node:
		var knockback_dir = (position - player_node.position).normalized()
		velocity = knockback_dir * 80
		velocity.y = -50
	
	print("Здоровье босса: ", health, "/", max_health)
	
	if health < max_health * 0.3:
		speed = 150
		attack_cooldown_time = 1.0
		touch_damage = 15
	
	if health <= 0:
		death()

# УРОН ОТ КАСАНИЯ - через Area2D
func _on_touch_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and alive and touch_cooldown <= 0:
		print("Босс касается игрока - наносит урон!")
		if body.has_method("take_damage"):
			body.take_damage(touch_damage)
		
		# Визуальный эффект
		show_touch_effect()
		
		# Кулдаун
		touch_cooldown = TOUCH_COOLDOWN_TIME

func show_touch_effect():
	# Эффект при касании
	modulate = Color(1.8, 0.9, 0.3)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.2)

# Уничтожение магии
func _on_magic_detector_area_entered(area: Area2D) -> void:
	if area.is_in_group("magic") and alive:
		print("Босс уничтожил магию!")
		if area.has_method("queue_free"):
			area.queue_free()
		elif area.get_parent().has_method("queue_free"):
			area.get_parent().queue_free()

func _on_detector_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and alive:
		print("Игрок обнаружен!")
		player_node = body
		chase = true
		
func _on_detector_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("Игрок потерян")
		chase = false

# В файле orc_boss.gd добавьте в функцию death():
func death():
	print("=== БОСС ПОБЕЖДЕН! ===")
	alive = false
	velocity = Vector2.ZERO
	
	# Отключаем коллизии
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true
	if has_node("detector/CollisionShape2D"):
		$detector/CollisionShape2D.disabled = true
	if has_node("TouchArea/CollisionShape2D"):
		$TouchArea/CollisionShape2D.disabled = true
	
	anim.play("death")
	spawn_rewards()
	
	# ЭМИССИЯ СИГНАЛА О ПОБЕДЕ
	emit_signal("boss_defeated")
	
	await get_tree().create_timer(2.0).timeout
	queue_free()

func spawn_rewards():
	var gold_coin_scene = preload("res://collectibles/gold.tscn")
	for i in range(15):
		var coin = gold_coin_scene.instantiate()
		get_parent().add_child(coin)
		var offset = Vector2(randf_range(-80, 80), randf_range(-50, -100))
		coin.position = position + offset
		if coin.has_method("apply_impulse"):
			var impulse = Vector2(randf_range(-100, 100), randf_range(-150, -200))
			coin.apply_impulse(impulse)
	
	print("Босс оставил награду!")
	
	
