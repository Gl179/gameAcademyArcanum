# MovingPlatform.gd (если файл уже есть)
extends Node2D

@export var speed: float = 50.0
@export var wait_time: float = 1.0
@export var loop_type: int = 0  # 0 - цикл, 1 - туда-обратно

func _ready():
	# Найди ноды пути и настрой их
	var path_follow = $Path2D/PathFollow2D
	if path_follow:
		path_follow.loop = (loop_type == 0)
