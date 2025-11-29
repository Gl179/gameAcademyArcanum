extends TouchScreenButton

@onready var player = get_tree().get_first_node_in_group("player")
var is_dash_unlocked: bool = false

func _ready() -> void:
	# Добавляем кнопку в группу для легкого доступа
	add_to_group("dash_buttons")
	
	# Сначала делаем кнопку невидимой
	visible = false
	modulate = Color(1, 1, 1, 0.3)
	
	# Ждем немного, чтобы игрок успел загрузиться
	await get_tree().create_timer(1.0).timeout
	check_dash_ability()

func _process(_delta: float) -> void:
	# Постоянно проверяем наличие способности
	if player and player.has_dash_ability:
		if not is_dash_unlocked:
			is_dash_unlocked = true
			visible = true
			show_with_effect()
	else:
		# Если игрок еще не найден, пытаемся найти
		if not player:
			player = get_tree().get_first_node_in_group("player")

func check_dash_ability():
	# Находим игрока, если еще не нашли
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	if player:
		if player.has_dash_ability:
			is_dash_unlocked = true
			visible = true
			show_with_effect()
			print("✓ Кнопка рывка активирована")
		else:
			is_dash_unlocked = false
			visible = false
			print("Кнопка рывка скрыта - способность не получена")

func show_with_effect():
	# Плавное появление кнопки
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.3)
	
	print("🎮 Кнопка рывка активирована!")

# Обработка нажатия - проверяем, доступна ли кнопка
func _on_pressed() -> void:
	if is_dash_unlocked and player and player.has_dash_ability:
		print("Кнопка рывка нажата")
		# Игрок сам обработает нажатие через свою функцию
