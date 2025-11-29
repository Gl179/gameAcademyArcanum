extends Node2D


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "player":
		body.take_damage(20)
