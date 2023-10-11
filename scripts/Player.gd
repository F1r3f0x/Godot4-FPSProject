extends CharacterBody3D

# UI node to draw debug stuff
@export var ui_node: Control

### Movement const variables
## Max speed on ground. Default: 10.0 - Quake default: 32.0
@export var MAX_SPEED : float = 10.0
	
## Speed when walking. Default: 4.0 - Quake default: 16.0
@export var WALK_SPEED : float = 4.0

## Player gravity. Default: 9.8 m/s - Quake default 80.0
@export var GRAVITY : float = ProjectSettings.get_setting("physics/3d/default_gravity")

## Acceleration on the ground. Default: 10.0 - Quake default: 10.0
@export var ACCELERATION_RATE : float = 10.0

## Ground movement friction. Default: 4.0 - Quake default: 6.0 (This is calculated differently)
@export var FRICTION : float = 4.0 

## This is applied when moving in the air. Default: 0.7 - Quake default: 0.7
@export var AIR_ACCELERATION_RATE : float = 0.7

## This acceleration applies when you stop pressing your movement keys. Default: 4.0 - Quake default: 10.0
@export var AIR_STOP_ACCELERATION : float = 4.0

## This scale is the dot product between your jump and current speed, between 0 and -1. Closer to zero is more punishing. Default: -0.5
@export var AIR_COUNTER_SCALE : float = -0.5

## Speed when jumping. Default: 4.5 - Quake default: 27.0
@export var JUMP_FORCE : float = 4.75 
	
## Constant to allow air control when going forwards, bigger values is more control. Default: 0.2 - Quake default: 0.0
@export var AIR_CONTROL : float = 0.2

## This time allows you to jump just after some drop. Defualt: 0.2
@export var MAX_HANG : float = 0.2

##


###

### Crouch const variables
@export var PLAYER_HEIGHT : float = 1.76    # default: 3.6
@export var CROUCH_HEIGHT : float = 1.0    # default: 2.
###

### Camera variables

## Mouse sensitivity scale factor, bigger is slower. Default: 0.009
@export var MOUSE_SENSITIVITY : float = 1000
###

### State variables
## Current max movement speed
var max_move_speed: float = 0.0
## Current forward direction scale. (Forwards - Backwards)
var forwards_move : float = 0.0
## Current sideways direction scale (Left - Right)
var sideways_move : float = 0.0
## Normal vector of the ground
var ground_normal : Vector3 = Vector3.UP
## Current hang time
var hang_time: float = 0.0
## Velocity at impact with the ground
var impact_velocity : float = 0.0
## True if jump was pressed
var jump_pressed: bool = false
## Velocity when jump has started
var jump_initial_velocity : Vector3

### Player state
enum {GROUNDED, FALLING, NOCLIP}
var state := GROUNDED

### Attached Nodes
@onready var head = $Head
@onready var camera = $Head/Camera

# Debug UI
var position_label : Label
var velocity_label : Label
var speed_label : Label
var air_acceleration_label : Label
var debug_air_acceleration : float = 0.0
var impact_velocity_label: Label

func _ready():
	# Capture mouse in game window
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Maximize game window
	#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	
	# Initialization of debug ui nodes
	if ui_node != null:
		position_label = ui_node.get_node('Position')
		velocity_label = ui_node.get_node('Velocity')
		speed_label = ui_node.get_node('Speed')
		air_acceleration_label = ui_node.get_node('AirAcceleration')
		impact_velocity_label = ui_node.get_node('ImpactVelocity')
		
		
	
func _input(event):
	# Handle Mouse input
	if event is InputEventMouseMotion:
		# Rotate BODY horizontally, use the relative mouse movement
		rotation.y -= event.relative.x * 1/MOUSE_SENSITIVITY
		# Rotate camera verticaly, use the relative mouse movement
		camera.rotation.x -= event.relative.y * 1/MOUSE_SENSITIVITY
		# Clamp the vertical rotation to 90°, rotation uses radians
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
	
	# Get forward move scale, this is used to create a wished direction for the player
	forwards_move = Input.get_action_strength("move_forward") - Input.get_action_strength("move_backwards")
	# Get sideways move scale, this is also a factor for the wished direction
	sideways_move = Input.get_action_strength("strafe_right") - Input.get_action_strength("strafe_left")
	
	# Set max current speed
	max_move_speed = MAX_SPEED # TODO: implement walk speed
	if Input.is_action_pressed("walk"):
		max_move_speed = WALK_SPEED
		
	# Handle the jump button, the !jump_pressed allows the player to queue the jump like in quake
	if Input.is_action_just_pressed("jump") and !jump_pressed:
		jump_pressed = true
	elif Input.is_action_just_released("jump"):
		jump_pressed = false
		
	# TODO: Handle crouch
	
	if Input.is_action_just_pressed("dev_reset"):
		position = Vector3.ZERO
		
		
func _physics_process(delta):
	
	# Check in which movement state are we
	movement_state()
	
	# Handle jump movement
	movement_jump(delta)
	
	# Handle directional movement
	if state == GROUNDED:
		movement_ground(delta)
		stair_stepping(delta)
				
	if state == FALLING:
		movement_air(delta)
		
	# All calculations are done, let godot handle collisions
	move_and_slide()
	
	# Update debug ui
	update_ui()


## Checks character movement state
func movement_state():
	if is_on_floor():
		state = GROUNDED
	else:
		state = FALLING


## Handles jump movement
func movement_jump(delta):
		# TODO: if is dead return
		
		# Allow jump for a few frames if just ran off platform
		if state != FALLING:
			# If on ground reset hang time
			hang_time = MAX_HANG
		else:
			# If on air reduce time. If hang time is < 0, clamp it to 0
			hang_time -= delta if hang_time > 0.0 else 0.0
		
		# Moving up too fast, don't jump. TODO: check how well this works
		if velocity.y > 54.0:
			return
		
		# if we have hang time and we pressed jumop
		if hang_time > 0.0 and jump_pressed:
			# We are now falling
			state = FALLING
			
			# Remove jump to recreate quake jump queue
			jump_pressed = false
			
			# Set hang time to zero because we are jumping
			hang_time = 0.0
			
			# Play hump sound
			$AudioPlayer3D.play()
			
			# Make sure jump velocity is positive if moving down
			if velocity.y < 0.0:
				velocity.y = JUMP_FORCE
			else:
				velocity.y += JUMP_FORCE
			
			# Store initial velocity for future calculations.
			jump_initial_velocity = Vector3(velocity.normalized())


## Handles player movement on the ground
func movement_ground(delta):
	var wish_velocity : Vector3 = get_wish_velocity()
	var wish_direction : Vector3 = wish_velocity.normalized()
	var wish_speed : float = wish_direction.length()
	
	ground_accelerate(wish_direction, slope_speed(ground_normal.y), delta)
	

func ground_accelerate(wish_direction : Vector3, wish_speed : float, delta : float):
	var friction_weight : float
	var target_velocity : Vector3
	
	if wish_direction != Vector3.ZERO:
		friction_weight = ACCELERATION_RATE * delta
		target_velocity = wish_direction * wish_speed
	else:
		friction_weight = FRICTION * delta
		target_velocity = Vector3.ZERO
		
	if friction_weight > 1:
			friction_weight = 1
			
	velocity = velocity.lerp(target_velocity, friction_weight)



func movement_air(delta):
	var wish_direction : Vector3 = get_wish_velocity()
	var velocity_normalized = velocity.normalized()
	var acceleration : float
	
	# Apply stop speed if pressing the inverse direction
	if velocity_normalized.dot(wish_direction) < 0:
		acceleration = AIR_STOP_ACCELERATION
	# Apply air acceleration if pressing going in a single direction, you also go diagonally
	else:
		acceleration = AIR_ACCELERATION_RATE
	
	var counter_scale = velocity_normalized.dot(jump_initial_velocity)
	if counter_scale < -0.5:
		acceleration = 0
	
	debug_air_acceleration = acceleration
	
	air_accelerate(wish_direction, acceleration, delta)
	
	# Air Control
	if state == FALLING:
		if AIR_CONTROL > 0.0:
			air_control(wish_direction, delta)
	
	# Add gravity
	velocity.y -= GRAVITY * delta
	
	impact_velocity = abs(int(round(velocity.y)))


func air_accelerate(wish_direction : Vector3, acceleration : float, delta : float):
	var wish_speed := slope_speed(ground_normal.y)
	
	# Quake air acceleration bug.
	# Instead of getting the real current speed, we substract the dot product between velocity and the wished direction
	var current_speed := velocity.dot(wish_direction)
	
	var add_speed = wish_speed - current_speed
	if add_speed <= 0.0: 
		return
	
	var acceleration_speed = acceleration * delta * wish_speed
	if acceleration_speed > add_speed: 
		acceleration_speed = add_speed
	
	velocity += acceleration_speed * wish_direction


func air_control(wish_direction: Vector3, delta : float):
	if forwards_move == 0.0: 
		return
	
	var original_y = velocity.y
	velocity.y = 0.0
	var speed = velocity.length()
	velocity = velocity.normalized()
	
	# Change direction while slowing down
	var dot = velocity.dot(wish_direction)
	if dot > 0.0 :
		var k = 32.0 * AIR_CONTROL * dot * dot * delta
		velocity = velocity * speed + wish_direction * k
		velocity = velocity.normalized()
	
	velocity.x *= speed
	velocity.y = original_y
	velocity.z *= speed

# Change velocity while moving up/down sloped ground
func slope_speed(y_normal : float) -> float:
	if y_normal <= 0.97:
		print('sloped')
		var multiplier = y_normal if velocity.y > 0.0 else 2.0 - y_normal
		return clamp(max_move_speed * multiplier, 5.0, max_move_speed * 1.2)
	return max_move_speed


func get_wish_velocity():
	var wish_velocity : Vector3 = (transform.basis.x * sideways_move - transform.basis.z * forwards_move)
	return wish_velocity
	

func stair_stepping(delta):
	## Check for stairs
	var check_step_length = 0.1
	var minimum_step_length = 0.1
	
	var velocity_direction = to_local(global_position + velocity.normalized())
	velocity_direction.y = 0
	
	# Reset Shape Cast
	$TestCast.position = Vector3.ZERO
	$TestCast.target_position = Vector3.ZERO
	
	var up_check_vector = check_step_length * Vector3.UP
	var hor_check_vector = velocity_direction * check_step_length

	# Cast height
	up_check_vector = 0.5 * Vector3.UP
	$TestCast.target_position = up_check_vector
	$TestCast.force_shapecast_update()

	var height_point = up_check_vector * $TestCast.get_closest_collision_safe_fraction()
	$TestCast.target_position = Vector3.ZERO

	# Cast Horizontal
	$TestCast.position = height_point
	$TestCast.target_position = hor_check_vector
	$TestCast.force_shapecast_update()
	
	var horizontal_point = Vector3(
		hor_check_vector.x * $TestCast.get_closest_collision_safe_fraction(),
		height_point.y * $TestCast.get_closest_collision_safe_fraction(),
		hor_check_vector.z * $TestCast.get_closest_collision_safe_fraction()
	)
	
	var step_diff = 0
	if $TestCast.is_colliding():
		# Get the diff betweem pos and step
		step_diff = -((global_position.y - $TestCast.get_collision_point(0).y) + 0.88)
		var hor2_check_pos = Vector3(
			0,
			position.y - (0.88 + step_diff), # Sets Testcast to the height of the step
			0
		)
		# Do another horizontal cast
		$TestCast.position = hor2_check_pos
		$TestCast.target_position = hor_check_vector
		$TestCast.force_shapecast_update()
		if !$TestCast.is_colliding():
			horizontal_point = hor_check_vector
			horizontal_point.y = (position.y - (0.88 +step_diff)) * $TestCast.get_closest_collision_safe_fraction()
		else:
			return
	
	# Cast Down
	var hor_down_check_vector = Vector3(
		0,
		-0.5,
		0
	)

	$TestCast.position = horizontal_point
	$TestCast.target_position = hor_down_check_vector
	$TestCast.force_shapecast_update()

	var cast_colliding = $TestCast.is_colliding()

	var stair_position =  $TestCast.position + (hor_down_check_vector * $TestCast.get_closest_collision_safe_fraction())
	var test_collision = move_and_collide(velocity * delta, true)
	if test_collision:
		var cast_player_diff = $TestCast.global_position - global_position
		var angle = rad_to_deg(test_collision.get_angle())
		var normal = test_collision.get_normal()
		print(normal, stair_position, angle)
		if abs(normal.y) != 1 and (normal.y == 0 or normal.y > 0.71) and stair_position.y < 0.5:
			position.y = to_global(stair_position).y


# Placeholder code to update debug ui
func update_ui():
	if ui_node == null:
		return
	
	# Update labels
	position_label.text = 'Position: %s' % global_position
	velocity_label.text = 'Velocity: %s' % velocity
	speed_label.text = 'Horizontal SPEED: %s m/s' % Vector2(velocity.x, velocity.z).length()
	air_acceleration_label.text = 'Air Acceleration: %s' % debug_air_acceleration
	if debug_air_acceleration == 0:
		air_acceleration_label.self_modulate = Color(255,0,0)
	else:
		air_acceleration_label.self_modulate = Color(0,255,0)
	impact_velocity_label.text = 'Impact Velocity: %s' % impact_velocity
