extends Camera2D

# Параметры камеры
const CAMERA_VERTICAL_OFFSET = 100.0  # Уменьшенная высота
const CAMERA_MOVE_SPEED = 1.5         # Медленная скорость движения ВВЕРХ/ВНИЗ
const CAMERA_RETURN_SPEED = 6.0       # Быстрая скорость возвращения НАЗАД
const DEAD_ZONE = 0.3                 # Мертвая зона для джойстика

var camera_target_y: float = 0.0      # Целевая позиция камеры по Y
var is_camera_active: bool = false    # Активно ли управление камерой
var player: CharacterBody2D           # Ссылка на игрока

func _ready():
	# Ищем игрока автоматически
	player = get_parent()
	if not player or not player is CharacterBody2D:
		print("Ошибка: Камера должна быть дочерней для игрока")
		set_process(false)

func _process(delta):
	if not player:
		return
	
	# Проверяем, можно ли управлять камерой
	check_camera_control()
	
	# Обработка ввода для камеры
	handle_camera_input(delta)
	
	# Плавное перемещение камеры
	move_camera(delta)

func check_camera_control():
	# Основные условия - на земле и не в активных действиях
	var basic_conditions = (
		player.is_on_floor() and 
		not player.get("is_attacking") and 
		not player.get("is_using_magic") and 
		not player.get("is_dead") and 
		not player.get("is_taking_damage") and 
		not player.get("is_dashing") and
		not player.get("is_charging_jump")
	)
	
	if basic_conditions:
		# Проверяем ввод джойстика/клавиш
		var horizontal_input = Input.get_axis("ui_left", "ui_right")
		var vertical_input = Input.get_axis("ui_up", "ui_down")
		
		# Если есть значительный ввод по горизонтали - отключаем камеру
		if abs(horizontal_input) > DEAD_ZONE:
			is_camera_active = false
			camera_target_y = 0.0
		# Если есть ввод по вертикали и нет движения - включаем камеру
		elif abs(vertical_input) > DEAD_ZONE and abs(player.velocity.x) < 10:
			is_camera_active = true
		# Если нет ввода - оставляем как есть
	else:
		is_camera_active = false
		camera_target_y = 0.0

func handle_camera_input(delta):
	if not is_camera_active:
		return
	
	var vertical_input := 0.0
	
	# Проверяем кнопки вверх/вниз
	if Input.is_action_pressed("ui_up"):
		vertical_input = -1.0  # Вверх
	elif Input.is_action_pressed("ui_down"):
		vertical_input = 1.0   # Вниз
	
	# Также проверяем аналоговый ввод (для джойстика)
	var analog_vertical = Input.get_axis("ui_up", "ui_down")
	if abs(analog_vertical) > DEAD_ZONE:
		vertical_input = analog_vertical
	
	if vertical_input != 0:
		# МЕДЛЕННО двигаем камеру вверх/вниз
		var target_y = vertical_input * CAMERA_VERTICAL_OFFSET
		camera_target_y = lerp(camera_target_y, target_y, CAMERA_MOVE_SPEED * delta)
	else:
		# БЫСТРО возвращаем камеру если нет ввода
		camera_target_y = lerp(camera_target_y, 0.0, CAMERA_RETURN_SPEED * delta)

func move_camera(delta):
	var current_y = position.y
	
	# Всегда плавно двигаем камеру к целевой позиции
	var new_y = lerp(current_y, camera_target_y, CAMERA_RETURN_SPEED * delta)
	
	# Если очень близко к цели - устанавливаем точно
	if abs(new_y - camera_target_y) < 0.5:
		new_y = camera_target_y
	
	position.y = new_y

# Принудительный сброс камеры
func reset_camera():
	position.y = 0
	camera_target_y = 0
	is_camera_active = false

# Получить статус камеры для отладки
func get_camera_status() -> String:
	return "Камера: Активна=%s, Цель_Y=%.1f, Поз_Y=%.1f" % [is_camera_active, camera_target_y, position.y]
