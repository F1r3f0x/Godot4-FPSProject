extends CharacterBody3D



func _physics_process(delta):
	
	if!is_on_floor():
		velocity.y = -9.8
	else:
		velocity.y = 0
	move_and_slide()
