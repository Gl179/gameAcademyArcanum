extends Camera2D

# Параметры камеры
const CAMERA_VERTICAL_OFFSET = 150.0  # Насколько высоко/низко может смотреть камера
const CAMERA_MOVE_SPEED = 4.0         # Скорость движения камеры (lerp factor)
const CAMERA_STAND_DELAY = 0.5        # Задержка перед активацией камеры когда игрок стоит

var camera_target_y: float = 0.0      # Целевая позиция камеры по Y
var camera_stand_timer: float = 0.0   # Таймер стояния на месте
var can_move_camera: bool = false     # Можно ли двигать камеру
var player: CharacterBody2D           # Ссылка на игрока

func _ready():
	# Ищем игрока автоматически
	player = get_parent()
	if not player or not player is CharacterBody2D:
		print("Ошибка: Камера должна быть дочерней для игрока (CharacterBody2D)")
		set_process(false)

func _process(delta):
	if not player:
		return
	
	# Проверяем условия для движения камеры
	var can_control_camera = (
		player.is_on_floor() and 
		not player.get("is_attacking") and 
		not player.get("is_using_magic") and 
		not player.get("is_dead") and 
		not player.get("is_taking_damage") and 
		not player.get("is_dashing") and
		not player.get("is_charging_jump")
	)
	
	# Проверяем стоит ли игрок на месте (нет движения по горизонтали)
	var is_standing = can_control_camera and abs(player.velocity.x) < 1.0
	
	if is_standing:
		# Игрок стоит - увеличиваем таймер
		camera_stand_timer += delta
		if camera_stand_timer >= CAMERA_STAND_DELAY:
			can_move_camera = true
	else:
		# Игрок движется - сбрасываем таймер и возвращаем камеру
		camera_stand_timer = 0.0
		can_move_camera = false
		camera_target_y = 0.0
	
	# Обработка ввода для камеры (вверх и вниз)
	var vertical_input := 0.0
	
	# Проверяем кнопки вверх/вниз
	if Input.is_action_pressed("ui_up"):
		vertical_input = -1.0  # Вверх
	elif Input.is_action_pressed("ui_down"):
		vertical_input = 1.0   # Вниз
	
	if vertical_input != 0 and can_move_camera:
		# Двигаем камеру вверх/вниз в зависимости от ввода
		camera_target_y = vertical_input * CAMERA_VERTICAL_OFFSET
	else:
		# Плавно возвращаем камеру в исходное положение если не можем управлять
		if not can_move_camera:
			camera_target_y = 0.0
	
	# Плавное перемещение камеры к целевой позиции
	var current_y = position.y
	var new_y = lerp(current_y, camera_target_y, CAMERA_MOVE_SPEED * delta)
	position.y = new_y

# Функция для принудительного сброса камеры
func reset_camera():
	position.y = 0
	camera_target_y = 0
	camera_stand_timer = 0.0
	can_move_camera = false

# Функция для проверки состояния камеры
func get_camera_status() -> String:
	var status = "Камера: "
	status += "Можно управлять: " + str(can_move_camera) + ", "
	status += "Таймер: " + str(camera_stand_timer) + ", "
	status += "Целевая Y: " + str(camera_target_y)
	return status
	
	
