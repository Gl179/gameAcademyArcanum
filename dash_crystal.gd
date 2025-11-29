extends Area2D

@onready var anim_sprite = $AnimatedSprite2D
@onready var collision = $CollisionShape2D
@onready var particles = $GPUParticles2D

var is_collected = false
var crystal_id = ""

func _ready():
	# Создаем уникальный ID на основе позиции
	crystal_id = "dash_crystal_" + str(int(global_position.x)) + "_" + str(int(global_position.y))
	
	# Проверяем, не собран ли уже кристалл
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager and save_manager.is_dash_crystal_collected(crystal_id):
		queue_free()
		return
	
	# Подключаем сигналы
	if body_entered.get_connections().is_empty():
		body_entered.connect(_on_body_entered)
	
	# Запускаем анимацию
	if anim_sprite:
		anim_sprite.play("idle")
	if particles:
		particles.emitting = true

func _on_body_entered(body):
	if body.is_in_group("player") and not is_collected:
		collect(body)

func collect(player):
	if is_collected:
		return
	
	is_collected = true
	if collision:
		collision.set_deferred("disabled", true)
	
	# Визуальные эффекты
	if particles:
		particles.emitting = true
	if anim_sprite:
		anim_sprite.visible = false
	
	# Даем игроку способность рывка
	if player.has_method("unlock_dash"):
		player.unlock_dash()
		print("✓ Получена способность: Рывок!")
	
	# СОЗДАЕМ СКРЫТУЮ ТОЧКУ СОХРАНЕНИЯ (без видимого кристалла)
	create_hidden_save_point()
	
	# Сохраняем в SaveManager
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager:
		save_manager.add_collected_dash_crystal(crystal_id)
	
	# Удаляем объект через секунду
	await get_tree().create_timer(1.0).timeout
	queue_free()

func create_hidden_save_point():
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager:
		# Создаем скрытую точку сохранения на этой позиции
		var hidden_save_id = "hidden_save_" + crystal_id
		save_manager.create_hidden_save_point(hidden_save_id, global_position)
		print("✓ Создана скрытая точка сохранения!")
