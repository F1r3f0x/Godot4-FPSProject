extends CharacterBody3D


@export var ignore_body: Node

func _physics_process(delta):
	pass
	
func move_separator(delta: float) -> bool:
	if!is_on_floor() and position.y >= -1.15:
		velocity.y = -5
	else:
		velocity.y = 0
	return move_and_slide()
	

func reset_separator():
	position = Vector3.ZERO
