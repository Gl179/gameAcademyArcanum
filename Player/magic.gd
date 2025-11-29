extends Area2D

@export var speed: float = 800.0
@export var damage: int = 50
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var velocity: Vector2 = Vector2.ZERO
var enemies_hit: Array = []
var distance_traveled: float = 0.0
var max_distance: float = 2000.0  # Максимальная дистанция полета

@onready var sprite = $Sprite2D

func _ready() -> void:
	# Добавляем в группу магии для обнаружения боссом
	add_to_group("magic")
	
	# Подключаем сигнал столкновения
	body_entered.connect(_on_body_entered)
	
	# Автоматически удаляем через время жизни
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

# Добавляем метод для получения направления (нужен боссу)
func get_direction() -> Vector2:
	return direction

func shoot(shoot_direction: Vector2, shoot_speed: float = 800.0) -> void:
	direction = shoot_direction.normalized()
	speed = shoot_speed
	velocity = direction * speed
	
	# Поворачиваем спрайт в направлении движения
	if direction.x < 0:
		sprite.flip_h = true

func _physics_process(delta: float) -> void:
	# Двигаем магию
	var movement = velocity * delta
	position += movement
	distance_traveled += movement.length()
	
	# Уничтожаем если пролетела слишком далеко
	if distance_traveled >= max_distance:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	# Проверяем, что это враг и мы его еще не били
	if body.is_in_group("enemies") and not _is_enemy_hit(body):
		# Наносим урон врагу
		if body.has_method("take_damage"):
			body.take_damage(damage)
			enemies_hit.append(body.get_instance_id())
			print("Magic dealt ", damage, " damage to enemy!")
		
		# Создаем эффект попадания
		create_hit_effect(body.global_position)

func _is_enemy_hit(body: Node2D) -> bool:
	var body_id = body.get_instance_id()
	for hit_id in enemies_hit:
		if hit_id == body_id:
			return true
	return false

func create_hit_effect(hit_position: Vector2) -> void:
	# Создаем эффект попадания
	var hit_effect = Sprite2D.new()
	hit_effect.texture = sprite.texture
	hit_effect.global_position = hit_position
	hit_effect.modulate = Color(1, 0.3, 0.3)
	hit_effect.scale = Vector2(0.8, 0.8)
	hit_effect.z_index = 10
	get_parent().add_child(hit_effect)
	
	# Анимация исчезновения
	var tween = create_tween()
	tween.tween_property(hit_effect, "modulate:a", 0.0, 0.4)
	tween.tween_property(hit_effect, "scale", Vector2(1.2, 1.2), 0.4)
	tween.tween_callback(hit_effect.queue_free)
