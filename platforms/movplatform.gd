extends Path2D

@export var loop := true
@export var speed := 100.0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$PathFollow2D.loop = loop


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	$PathFollow2D.progress += speed * delta
