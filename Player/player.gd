extends CharacterBody2D

# ОСНОВНЫЕ ПАРАМЕТРЫ
const SPEED = 110.0
const MAX_JUMP_VELOCITY = -300.0
const MIN_JUMP_VELOCITY = -100.0
const JUMP_CHARGE_TIME = 0.3
const GRAVITY = 980.0

# ИНЕРЦИЯ
const ACCELERATION = 0.2
const FRICTION = 0.08
const AIR_ACCELERATION = 0.1
const AIR_FRICTION = 0.05

# АТАКА
const NORMAL_ATTACK_DAMAGE = 100
const SUPER_ATTACK_DAMAGE = 200
const SUPER_ATTACK_HOLD_TIME = 0.5

# МАГИЯ
const MAGIC_COOLDOWN = 1.0
const MAGIC_SPEED = 500.0
const MAGIC_DAMAGE = 50

# РЫВОК
const DASH_SPEED = 310.0
const DASH_DURATION = 0.2
const DASH_COOLDOWN = 0.5
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var can_dash: bool = false
var has_dash_ability: bool = false

# НЕУЯЗВИМОСТЬ
const INVULNERABILITY_DURATION = 2.0

@onready var anim = $AnimatedSprite2D
var attack_area: Area2D

# ЗДОРОВЬЕ И СТАТУСЫ
var health = 100
var gold = 0
var is_dead: bool = false
var is_invulnerable: bool = false
var invulnerability_timer: float = 0.0
var is_taking_damage: bool = false
var damage_timer: float = 0.0
const DAMAGE_ANIMATION_DURATION = 0.3

# ПРЫЖОК С ЗАРЯДОМ
var jump_charge: float = 0.0
var is_charging_jump: bool = false
var was_on_floor: bool = false
var fall_velocity: float = 0.0

# АТАКА
var is_attacking: bool = false
var is_using_magic: bool = false
var attack_timer: float = 0.0
var magic_timer: float = 0.0
var current_attack_damage: int = NORMAL_ATTACK_DAMAGE

# МАГИЯ
var magic_cooldown_timer: float = 0.0
var can_use_magic: bool = true
@onready var magic_scene = preload("res://Player/magic.tscn")

# УСИЛЕННАЯ АТАКА
var x_button_pressed: bool = false
var x_button_hold_time: float = 0.0
var y_button_pressed: bool = false
var is_attack_charged: bool = false

# УПРАВЛЕНИЕ
var touch_jump_pressed: bool = false
var touch_jump_just_pressed: bool = false
var dash_button_pressed: bool = false

# ВИЗУАЛЬНЫЕ ИНДИКАТОРЫ
@onready var jump_charge_bar = $JumpChargeBar
@onready var attack_charge_bar = $AttackChargeBar
@onready var magic_cooldown_bar = $MagicCooldownBar

func _ready() -> void:
	add_to_group("player")
	setup_attack_area()
	setup_charge_bars()
	load_abilities()

func setup_attack_area():
	attack_area = get_node_or_null("AttackArea")
	if not attack_area:
		attack_area = Area2D.new()
		attack_area.name = "AttackArea"
		add_child(attack_area)
	
	var collision = attack_area.get_node_or_null("CollisionShape2D")
	if not collision:
		collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(80, 50)
		collision.shape = shape
		attack_area.add_child(collision)
	
	attack_area.monitoring = false
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	
	# Инициализируем позицию коллизии
	update_attack_area_position()

func update_attack_area_position():
	if attack_area and attack_area.has_node("CollisionShape2D"):
		var collision = attack_area.get_node("CollisionShape2D")
		# Смещаем область атаки вперед в направлении взгляда игрока
		if anim.flip_h:
			collision.position = Vector2(-40, 0)  # Влево
		else:
			collision.position = Vector2(40, 0)   # Вправо

func setup_charge_bars():
	# Создаем индикатор заряда прыжка
	jump_charge_bar = get_node_or_null("JumpChargeBar")
	if not jump_charge_bar:
		jump_charge_bar = ColorRect.new()
		jump_charge_bar.name = "JumpChargeBar"
		jump_charge_bar.size = Vector2(50, 5)
		jump_charge_bar.color = Color(0, 1, 0)
		jump_charge_bar.position = Vector2(-25, -60)
		add_child(jump_charge_bar)
	
	# Создаем индикатор заряда атаки
	attack_charge_bar = get_node_or_null("AttackChargeBar")
	if not attack_charge_bar:
		attack_charge_bar = ColorRect.new()
		attack_charge_bar.name = "AttackChargeBar"
		attack_charge_bar.size = Vector2(50, 5)
		attack_charge_bar.color = Color(1, 0, 0)
		attack_charge_bar.position = Vector2(-25, -50)
		add_child(attack_charge_bar)
	
	# Создаем индикатор перезарядки магии
	magic_cooldown_bar = get_node_or_null("MagicCooldownBar")
	if not magic_cooldown_bar:
		magic_cooldown_bar = ColorRect.new()
		magic_cooldown_bar.name = "MagicCooldownBar"
		magic_cooldown_bar.size = Vector2(50, 5)
		magic_cooldown_bar.color = Color(0, 0.5, 1)
		magic_cooldown_bar.position = Vector2(-25, -40)
		add_child(magic_cooldown_bar)
	
	# Создаем индикатор перезарядки рывка
	var dash_cooldown_bar = get_node_or_null("DashCooldownBar")
	if not dash_cooldown_bar:
		dash_cooldown_bar = ColorRect.new()
		dash_cooldown_bar.name = "DashCooldownBar"
		dash_cooldown_bar.size = Vector2(50, 5)
		dash_cooldown_bar.color = Color(0.5, 0, 1)
		dash_cooldown_bar.position = Vector2(-25, -30)
		add_child(dash_cooldown_bar)
	
	# Скрываем индикаторы в начале
	jump_charge_bar.visible = false
	attack_charge_bar.visible = false
	magic_cooldown_bar.visible = false
	dash_cooldown_bar.visible = false

func load_abilities():
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager:
		var abilities = save_manager.get_player_abilities()
		has_dash_ability = abilities["has_dash_ability"]
		if has_dash_ability:
			can_dash = true
			print("✓ Способность 'Рывок' загружена из сохранения")

func unlock_dash():
	has_dash_ability = true
	can_dash = true
	print("Способность 'Рывок' разблокирована!")
	
	# УВЕДОМЛЯЕМ КНОПКУ РЫВКА
	notify_dash_button()

func notify_dash_button():
	# Ищем все кнопки рывка в группе
	var dash_buttons = get_tree().get_nodes_in_group("dash_buttons")
	print("Найдено кнопок рывка: ", dash_buttons.size())
	
	for button in dash_buttons:
		if button.has_method("check_dash_ability"):
			button.check_dash_ability()
			print("Уведомление отправлено кнопке: ", button.name)

func start_dash():
	if not has_dash_ability or not can_dash or is_dashing or is_attacking or is_using_magic:
		return
	
	is_dashing = true
	can_dash = false
	dash_timer = DASH_DURATION
	dash_cooldown_timer = DASH_COOLDOWN
	
	# Устанавливаем скорость рывка
	var dash_direction = Vector2.RIGHT if not anim.flip_h else Vector2.LEFT
	velocity = dash_direction * DASH_SPEED
	
	# Визуальные эффекты
	anim.play("Dash")
	start_dash_effect()
	
	print("Рывок!")

func start_dash_effect():
	# Эффект прозрачности во время рывка
	modulate = Color(1, 1, 1, 0.7)
	
	# Можно добавить следы/частицы
	var dash_particles = GPUParticles2D.new()
	add_child(dash_particles)
	await get_tree().create_timer(DASH_DURATION).timeout
	dash_particles.queue_free()

func stop_dash():
	is_dashing = false
	modulate = Color(1, 1, 1, 1)
	# Плавное замедление после рывка
	velocity.x *= 0.5

func _physics_process(delta: float) -> void:
	if is_dead:
		if not is_on_floor():
			velocity.y += GRAVITY * delta
			move_and_slide()
		return
	
	# Обновление таймеров рывка
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			stop_dash()
	
	if not can_dash and not is_dashing:
		dash_cooldown_timer -= delta
		if dash_cooldown_timer <= 0:
			can_dash = true
	
	# Обновление таймера неуязвимости
	if is_invulnerable:
		invulnerability_timer -= delta
		if invulnerability_timer <= 0:
			is_invulnerable = false
			modulate = Color(1, 1, 1, 1)
	
	# Обновление таймера анимации урона
	if is_taking_damage:
		damage_timer -= delta
		if damage_timer <= 0:
			is_taking_damage = false
	
	# Обновление таймера перезарядки магии
	if not can_use_magic:
		magic_cooldown_timer -= delta
		update_magic_cooldown_indicator()
		if magic_cooldown_timer <= 0:
			can_use_magic = true
			magic_cooldown_bar.visible = false
	
	# Обновление таймеров анимаций
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0:
			is_attacking = false
			if attack_area:
				attack_area.monitoring = false
	
	if is_using_magic:
		magic_timer -= delta
		if magic_timer <= 0:
			is_using_magic = false
	
	# Обработка удержания кнопки X для супер атаки
	if x_button_pressed and not is_attacking and not is_using_magic and not is_dead and not is_taking_damage:
		x_button_hold_time += delta
		
		# Обновляем индикатор заряда атаки
		update_attack_charge_indicator()
		
		# Если атака зарядилась - включаем визуальный эффект
		if x_button_hold_time >= SUPER_ATTACK_HOLD_TIME and not is_attack_charged:
			is_attack_charged = true
			start_attack_charge_effect()
		
		if x_button_hold_time >= SUPER_ATTACK_HOLD_TIME and not is_attacking:
			start_super_attack()
	
	# Гравитация
	if not is_on_floor() and not is_dashing:
		velocity.y += GRAVITY * delta
		if velocity.y > 0:
			fall_velocity = velocity.y
	
	# Определяем, когда персонаж только что приземлился
	var just_landed = is_on_floor() and not was_on_floor
	
	# Обработка прыжка с зарядом
	var jump_input_pressed = Input.is_action_pressed("ui_accept") or touch_jump_pressed
	var jump_input_just_pressed = Input.is_action_just_pressed("ui_accept") or touch_jump_just_pressed

	if jump_input_just_pressed and is_on_floor() and not is_attacking and not is_using_magic and not is_taking_damage and not is_dashing:
		is_charging_jump = true
		jump_charge = 0.0
		velocity.y = MIN_JUMP_VELOCITY
		anim.play("Jump")
		jump_charge_bar.visible = true

	if is_charging_jump and jump_input_pressed:
		jump_charge += delta
		jump_charge = min(jump_charge, JUMP_CHARGE_TIME)
		
		# Обновляем индикатор заряда прыжка
		update_jump_charge_indicator()
		
		var jump_factor = jump_charge / JUMP_CHARGE_TIME
		var target_velocity = lerp(MIN_JUMP_VELOCITY, MAX_JUMP_VELOCITY, jump_factor)
		
		if velocity.y < 0:
			velocity.y = min(velocity.y, target_velocity)

	if is_charging_jump and (not jump_input_pressed or jump_charge >= JUMP_CHARGE_TIME):
		is_charging_jump = false
		jump_charge_bar.visible = false

	if just_landed:
		is_charging_jump = false
		jump_charge = 0.0
		jump_charge_bar.visible = false

	# Обработка обычной атаки
	if (Input.is_action_just_pressed("attack") or (x_button_pressed and x_button_hold_time == 0)) and not is_attacking and not is_using_magic and not is_dead and not is_taking_damage and not is_dashing:
		start_normal_attack()
	
	# Обработка магии
	if (Input.is_action_just_pressed("magic") or y_button_pressed) and not is_attacking and not is_using_magic and not is_dead and not is_taking_damage and not is_dashing and can_use_magic:
		use_magic()
	
	# Обработка рывка
	if (Input.is_action_just_pressed("dash") or dash_button_pressed) and has_dash_ability and not is_dashing:
		start_dash()

	# СИСТЕМА ДВИЖЕНИЯ С ИНЕРЦИЕЙ
	var direction := Input.get_axis("ui_left", "ui_right")
	
	if not is_attacking and not is_using_magic and not is_dead and not is_taking_damage and not is_dashing:
		if direction != 0:
			# Ускорение при движении с использованием lerp для плавности
			var target_velocity_x = direction * SPEED
			var acceleration = ACCELERATION if is_on_floor() else AIR_ACCELERATION
			
			velocity.x = lerp(velocity.x, target_velocity_x, acceleration)
			
			# Поворот спрайта и обновление позиции коллизии атаки
			var old_flip_h = anim.flip_h
			if direction < 0:
				anim.flip_h = true
			else:
				anim.flip_h = false
			
			# Если направление изменилось, обновляем позицию области атаки
			if old_flip_h != anim.flip_h:
				update_attack_area_position()
			
			# Анимация бега только на земле
			if is_on_floor() and not is_charging_jump:
				anim.play("Run")
		else:
			# Замедление при остановке с использованием lerp для плавности
			var friction = FRICTION if is_on_floor() else AIR_FRICTION
			velocity.x = lerp(velocity.x, 0.0, friction)
			
			# Анимация покоя только когда на земле
			if is_on_floor() and not is_charging_jump and not just_landed:
				anim.play("Idle")
	
	# Анимация прыжка/падения
	if not is_on_floor() and not is_attacking and not is_using_magic and not is_dead and not is_taking_damage and not is_dashing:
		if velocity.y < 0:
			anim.play("Jump")
		else:
			anim.play("Fall")
	
	# Анимация рывка
	if is_dashing:
		anim.play("Dash")

	# Логика смерти
	if health <= 0 and not is_dead:
		die()
	
	was_on_floor = is_on_floor()
	touch_jump_just_pressed = false
	dash_button_pressed = false
	
	move_and_slide()

func update_jump_charge_indicator():
	if jump_charge_bar:
		var charge_ratio = jump_charge / JUMP_CHARGE_TIME
		jump_charge_bar.size.x = 50 * charge_ratio
		
		# Меняем цвет в зависимости от заряда
		if charge_ratio < 0.5:
			jump_charge_bar.color = Color(0, 1, 0)
		elif charge_ratio < 0.8:
			jump_charge_bar.color = Color(1, 1, 0)
		else:
			jump_charge_bar.color = Color(1, 0, 0)

func update_attack_charge_indicator():
	if attack_charge_bar:
		var charge_ratio = x_button_hold_time / SUPER_ATTACK_HOLD_TIME
		attack_charge_bar.size.x = 50 * charge_ratio
		attack_charge_bar.visible = true
		
		# Меняем цвет в зависимости от заряда
		if charge_ratio < 0.5:
			attack_charge_bar.color = Color(1, 0.5, 0)
		elif charge_ratio < 1.0:
			attack_charge_bar.color = Color(1, 0, 0)
		else:
			attack_charge_bar.color = Color(1, 0, 1)

func update_magic_cooldown_indicator():
	if magic_cooldown_bar:
		var cooldown_ratio = 1.0 - (magic_cooldown_timer / MAGIC_COOLDOWN)
		magic_cooldown_bar.size.x = 50 * cooldown_ratio
		magic_cooldown_bar.visible = true
		
		# Меняем цвет в зависимости от перезарядки
		if cooldown_ratio < 0.7:
			magic_cooldown_bar.color = Color(0, 0.5, 1)
		else:
			magic_cooldown_bar.color = Color(0.5, 0, 1)

func start_attack_charge_effect():
	# Эффект мигания белым при полной зарядке атаки
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "modulate", Color(1.5, 1.5, 1.5), 0.1)
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.1)

func stop_attack_charge_effect():
	# Останавливаем эффект мигания и возвращаем нормальный цвет
	modulate = Color(1, 1, 1)
	var tweens = get_tree().get_processed_tweens()
	for tween in tweens:
		if tween.is_valid():
			tween.kill()

func start_normal_attack():
	is_attacking = true
	current_attack_damage = NORMAL_ATTACK_DAMAGE
	attack_timer = 0.6
	anim.play("Attak")
	print("Normal attack!")
	
	# Сбрасываем заряд атаки
	is_attack_charged = false
	stop_attack_charge_effect()
	
	# Активируем область атаки через небольшой промежуток времени
	await get_tree().create_timer(0.2).timeout
	if is_attacking and attack_area:
		attack_area.monitoring = true

func start_super_attack():
	is_attacking = true
	current_attack_damage = SUPER_ATTACK_DAMAGE
	attack_timer = 0.8
	anim.play("Attak_supper")
	print("Super attack!")
	
	# Сбрасываем таймер и скрываем индикатор
	x_button_hold_time = 0.0
	attack_charge_bar.visible = false
	is_attack_charged = false
	stop_attack_charge_effect()
	
	# Активируем область атаки через небольшой промежуток времени
	await get_tree().create_timer(0.2).timeout
	if is_attacking and attack_area:
		attack_area.monitoring = true

func use_magic() -> void:
	if not can_use_magic:
		return
	
	is_using_magic = true
	can_use_magic = false
	magic_cooldown_timer = MAGIC_COOLDOWN
	magic_timer = 0.8
	anim.play("magic")
	print("Magic cast!")
	
	# Ждем пока анимация магии не дойдет до определенного кадра или времени
	await get_tree().create_timer(0.3).timeout
	
	# Создаем экземпляр магии только после задержки
	create_magic_projectile()
	
	# Показываем индикатор перезарядки
	magic_cooldown_bar.visible = true

func create_magic_projectile() -> void:
	# Создаем экземпляр магии
	var magic_obj = magic_scene.instantiate()
	get_parent().add_child(magic_obj)
	
	# Устанавливаем позицию магии на уровне игрока
	var spawn_offset = Vector2(30, 0)  # Смещение вперед, на уровне игрока
	if anim.flip_h:
		spawn_offset.x = -spawn_offset.x
	
	magic_obj.global_position = global_position + spawn_offset
	
	# Запускаем движение магии
	var direction = Vector2.RIGHT if not anim.flip_h else Vector2.LEFT
	if magic_obj.has_method("shoot"):
		magic_obj.shoot(direction, MAGIC_SPEED)
		print("Magic projectile created at position: ", magic_obj.global_position)
	else:
		print("ERROR: Magic instance doesn't have shoot method!")

func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and is_attacking:
		if body.has_method("take_damage"):
			body.take_damage(current_attack_damage)
			print("Dealt ", current_attack_damage, " damage to enemy")

func take_damage(damage_amount: int) -> void:
	if is_dead or is_invulnerable or is_dashing:
		print("Player is invulnerable or dead, no damage taken")
		return
	
	health -= damage_amount
	
	# Активируем неуязвимость
	is_invulnerable = true
	invulnerability_timer = INVULNERABILITY_DURATION
	
	# Активируем анимацию урона
	is_taking_damage = true
	damage_timer = DAMAGE_ANIMATION_DURATION
	
	# Визуальный эффект неуязвимости (мигание)
	start_invulnerability_effect()
	
	if health > 0:
		anim.play("Damage")
		print("Player took damage: ", damage_amount, ". Health: ", health)
		
		# Легкий отскок при получении урона
		velocity.y = -200
		velocity.x = -100 if anim.flip_h else 100
	else:
		health = 0
		print("Player died!")

func start_invulnerability_effect() -> void:
	var tween = create_tween()
	tween.set_loops(8)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0.3), 0.125)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.125)

func die() -> void:
	is_dead = true
	anim.play("Deadh")
	print("Player died!")
	
	# Останавливаем движение
	velocity = Vector2.ZERO
	
	# Скрываем индикаторы и эффекты
	jump_charge_bar.visible = false
	attack_charge_bar.visible = false
	magic_cooldown_bar.visible = false
	stop_attack_charge_effect()
	
	# Ждем завершения анимации смерти
	await get_tree().create_timer(1.5).timeout
	
	# ВОЗРОЖДЕНИЕ У КРИСТАЛЛА
	respawn_at_crystal()

func respawn_at_crystal() -> void:
	print("Возрождение у кристалла...")
	
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager:
		var save_data = save_manager.get_save_data()
		
		# Сначала проверяем обычные кристаллы
		if save_data["player_data"]["position"]["x"] != 0:
			# Восстанавливаем у обычного кристалла
			global_position = Vector2(
				save_data["player_data"]["position"]["x"],
				save_data["player_data"]["position"]["y"]
			)
			print("✓ Возрожден у обычного кристалла сохранения")
		else:
			# Если нет обычного сохранения, ищем ближайшую скрытую точку
			var hidden_save = save_manager.get_nearest_hidden_save_point(global_position)
			if hidden_save and not hidden_save.is_empty():
				global_position = hidden_save["position"]
				print("✓ Возрожден у скрытой точки сохранения!")
			else:
				# Если скрытых точек нет - начинаем с начала уровня
				respawn_at_start()
				return
		
		# Восстанавливаем характеристики
		health = save_data["player_data"]["health"]
		gold = save_data["player_data"]["gold"]
		
		# Сбрасываем состояние
		reset_after_respawn()
		
		print("✓ Возрожден! Позиция: ", global_position)
	else:
		respawn_at_start()

func reset_after_respawn() -> void:
	is_dead = false
	is_invulnerable = true
	invulnerability_timer = 3.0  # 3 секунды неуязвимости
	velocity = Vector2.ZERO
	
	# Визуальные эффекты
	start_respawn_effect()
	
	# Сбрасываем все таймеры и состояния
	is_attacking = false
	is_using_magic = false
	is_taking_damage = false
	is_dashing = false
	can_dash = true
	
	# Убираем области атаки
	if attack_area:
		attack_area.monitoring = false

func respawn_at_start() -> void:
	print("Возрождение в начале уровня")
	get_tree().reload_current_scene()

func start_respawn_effect() -> void:
	# Эффект появления
	modulate = Color(1, 1, 1, 0.3)
	
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 2.0)
	tween.set_parallel(true)
	
	# Мигание во время неуязвимости
	var blink_tween = create_tween()
	blink_tween.set_loops(6)  # 6 миганий за 3 секунды
	blink_tween.tween_property(self, "modulate", Color(1, 1, 1, 0.5), 0.25)
	blink_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.25)
	
	anim.play("Idle")

func get_gold() -> int:
	return gold

func add_gold(amount: int):
	gold += amount

func collect_gold(amount: int) -> void:
	add_gold(amount)
	print("Collected ", amount, " gold. Total: ", gold)

# СЕНСОРНЫЕ КНОПКИ
func _on_touch_screen_button_pressed() -> void:
	touch_jump_pressed = true
	touch_jump_just_pressed = true

func _on_touch_screen_button_released() -> void:
	touch_jump_pressed = false

func _on_x_botton_pressed() -> void:
	x_button_pressed = true
	x_button_hold_time = 0.0

func _on_x_botton_released() -> void:
	x_button_pressed = false
	
	# Если отпустили кнопку до полного заряда - обычная атака
	if x_button_hold_time < SUPER_ATTACK_HOLD_TIME and x_button_hold_time > 0 and not is_attacking and not is_using_magic and not is_dead and not is_taking_damage:
		start_normal_attack()
	
	x_button_hold_time = 0.0
	attack_charge_bar.visible = false
	
	# Если была заряжена атака, но не использована - сбрасываем эффект
	if is_attack_charged:
		is_attack_charged = false
		stop_attack_charge_effect()

func _on_y_botton_pressed() -> void:
	y_button_pressed = true
	if not is_attacking and not is_using_magic and not is_dead and not is_taking_damage and can_use_magic:
		use_magic()

func _on_y_botton_released() -> void:
	y_button_pressed = false

func _on_a_botton_pressed() -> void:
	touch_jump_pressed = true
	touch_jump_just_pressed = true

func _on_a_botton_released() -> void:
	touch_jump_pressed = false

# Кнопка рывка
func _on_botton_dash_pressed() -> void:
	dash_button_pressed = true
	if has_dash_ability:
		start_dash()

func _on_botton_dash_released() -> void:
	dash_button_pressed = false

#перезагрузить уровень
func _on_restart_pressed() -> void:
	get_tree().change_scene_to_file("res://level.tscn")

#выйти в главное меню
func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")

func _on_b_botton_pressed() -> void:
	print("Кнопка B нажата - поиск кристаллов...")
	
	var crystals = get_tree().get_nodes_in_group("save_crystals")
	print("Найдено кристаллов: ", crystals.size())
	
	for crystal in crystals:
		if crystal.has_method("interact"):
			if crystal.player_in_range and crystal.is_active:
				print("Взаимодействуем с кристаллом: ", crystal.name)
				crystal.interact()
				return
			elif crystal.player_in_range and not crystal.is_active:
				print("Кристалл перезаряжается...")
				show_message("Кристалл перезаряжается")
				return
	
	print("Активных кристаллов для сохранения не найдено")

func show_message(text: String):
	# Добавьте систему сообщений для игрока
	print("Сообщение игроку: ", text)

func show_heal_effect():
	# Визуальный эффект лечения (зеленое свечение)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(0.5, 1, 0.5), 0.3)
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.3)
	tween.set_loops(2)
	
	# Можно добавить частицы лечения если есть
	print("Эффект лечения активирован!")
