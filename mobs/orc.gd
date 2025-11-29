extends CharacterBody2D

@onready var anim = $AnimatedSprite2D
var attack_area: Area2D

var speed = 50
var health = 200
var chase = false
var alive = true
var can_attack: bool = true
var is_attacking: bool = false
var is_taking_damage: bool = false
var damage_timer: float = 0.0
const DAMAGE_ANIMATION_DURATION = 0.3
var player_node: Node2D = null

const GRAVITY = 980.0

func _ready() -> void:
	add_to_group("enemies")
	find_player()
	setup_attack_area()
	
	# Проверяем, должен ли враг быть мертвым при загрузке
	check_saved_state()

func check_saved_state():
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager:
		var save_data = save_manager.get_save_data()
		var enemy_id = "enemy_" + str(int(global_position.x)) + "_" + str(int(global_position.y))
		
		if enemy_id in save_data["killed_enemies"]:
			# Этот враг должен быть мертв
			queue_free()
			print("Враг удален по сохранению: ", enemy_id)

func is_alive():
	return alive

# Остальной код orc.gd остается без изменений...
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
		shape.size = Vector2(80, 60)
		collision.shape = shape
		attack_area.add_child(collision)
	
	attack_area.monitoring = false
	attack_area.body_entered.connect(_on_attack_area_body_entered)

func update_attack_area_position():
	if attack_area and attack_area.has_node("CollisionShape2D"):
		var collision = attack_area.get_node("CollisionShape2D")
		if anim.flip_h:
			collision.position = Vector2(-40, 20)
		else:
			collision.position = Vector2(40, 20)

func find_player():
	player_node = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if not alive:
		return
	
	if is_taking_damage:
		damage_timer -= delta
		if damage_timer <= 0:
			is_taking_damage = false
	
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	
	if chase and not is_attacking and alive and not is_taking_damage:
		if not player_node:
			find_player()
			if not player_node:
				chase = false
				return
		
		var direction = (player_node.position - position).normalized()
		velocity.x = direction.x * speed
		
		var old_flip_h = anim.flip_h
		anim.flip_h = direction.x < 0
		
		if old_flip_h != anim.flip_h:
			update_attack_area_position()
		
		if not is_attacking and not is_taking_damage:
			anim.play("walk")
		
		var distance = position.distance_to(player_node.position)
		# Уменьшаем дистанцию для атаки, чтобы орк подбегал ближе
		if distance < 60 and can_attack and not is_attacking and not is_taking_damage:
			attack_player()
	else:
		velocity.x = 0
		if not is_attacking and alive and not is_taking_damage:
			anim.play("Idle")
	
	move_and_slide()

func attack_player():
	if not can_attack or is_attacking or is_taking_damage:
		return
	
	can_attack = false
	is_attacking = true
	velocity.x = 0
	
	anim.play("Attak")
	
	await get_tree().create_timer(0.2).timeout
	if is_attacking and attack_area:
		attack_area.monitoring = true
	
	await get_tree().create_timer(0.3).timeout
	if attack_area:
		attack_area.monitoring = false
	
	await get_tree().create_timer(0.1).timeout
	is_attacking = false
	can_attack = true

func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and is_attacking:
		if body.has_method("take_damage"):
			body.take_damage(20)

func take_damage(damage_amount: int) -> void:
	if not alive or is_taking_damage:
		return
	
	health -= damage_amount
	
	is_taking_damage = true
	damage_timer = DAMAGE_ANIMATION_DURATION
	
	if is_attacking and attack_area:
		is_attacking = false
		can_attack = true
		attack_area.monitoring = false
	
	anim.play("hurt")
	velocity.x = 0
	
	if health <= 0:
		death()

func _on_detector_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and alive:
		player_node = body
		chase = true
		
func _on_detector_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		chase = false

func spawn_gold_coins() -> void:
	var gold_coin_scene = preload("res://collectibles/gold.tscn")
	
	for i in range(3):
		var coin = gold_coin_scene.instantiate()
		get_parent().add_child(coin)
		
		var offset = Vector2(randf_range(-30, 30), randf_range(-20, -40))
		coin.position = position + offset
		
		if coin.has_method("apply_impulse"):
			var impulse = Vector2(randf_range(-50, 50), randf_range(-80, -120))
			coin.apply_impulse(impulse)

func death():
	alive = false
	velocity = Vector2.ZERO
	
	$CollisionShape2D.disabled = true
	$detector/CollisionShape2D.disabled = true
	if has_node("Death2/CollisionShape2D"):
		$Death2/CollisionShape2D.disabled = true
	if attack_area:
		attack_area.monitoring = false
	
	anim.play("death")
	
	spawn_gold_coins()
	
	await get_tree().create_timer(0.8).timeout
	queue_free()
