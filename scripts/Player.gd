extends CharacterBody3D

# UI node to draw debug stuff
@export var ui_node: Control

### Movement const variables
## Max speed on ground. Quake default: 32.0
@export var MAX_SPEED : float = 9.0

@export var FORWARD_SPEED: float = 10.0

@export var SIDEWAYS_SPEED: float = 12.0

@export var BACK_SPEED:	float = 10.0

## Speed when walking. Quake default: 16.0
@export var WALK_SPEED : float = 5.0

## Player gravity. Quake default 80.0
@export var GRAVITY : float = ProjectSettings.get_setting("physics/3d/default_gravity")

## Acceleration on the ground. Quake default: 10.0
@export var ACCELERATION_RATE : float = 10.0

## Ground movement friction. Default: 4.0 - Quake default: 6.0 (This is calculated differently)
@export var FRICTION : float = 4.0

@export var MAX_AIR_SPEED : float = 1.0

## This is applied when moving in the air. Quake default: 0.7
@export var AIR_ACCELERATION_RATE : float = 0.7

## This acceleration applies when you stop pressing your movement keys. Quake default: 10.0
@export var AIR_STOP_ACCELERATION : float = 4.0

## Speed when jumping. Quake default: 27.0
@export var JUMP_FORCE : float = 4.75

## Constant to allow air control when going forwards, bigger values is more control. Quake default: 0.0
@export var AIR_CONTROL : float = 0.2

## This time allows you to jump just after some drop. 
@export var MAX_HANG : float = 0.2

## Horizontal length to send the stair step test.
@export var HOR_CHECK_STEP_LENGTH: float = 0.15

## Vertical length to send the stair step test.
@export var VER_CHECK_STEP_LENGTH : float = 0.5

## Max normal allowed for stair stepping.
@export var MAX_STAIR_STEP_NORMAL : float = 0.71
##


### Crouch const variables
@export var PLAYER_HEIGHT : float = 1.76		# default: 1.76
@export var PLAYER_HALF_HEIGHT : float = 0.88	# default: 0.88 
@export var CROUCH_HEIGHT : float = 0.8    		# default: 0.8
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

var is_crouching: bool = false

### Player state
enum {GROUNDED, FALLING, NOCLIP}
var state := GROUNDED

### Attached Nodes
var test_cast: ShapeCast3D
var collider: CollisionShape3D

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

	# Get Nodes
	test_cast = $TestCast
	collider = $BodyCollision

	# Initialization of debug ui nodes
	if ui_node != null:
		position_label = ui_node.get_node('Position')
		velocity_label = ui_node.get_node('Velocity')
		speed_label = ui_node.get_node('Speed')
		air_acceleration_label = ui_node.get_node('AirAcceleration')
		impact_velocity_label = ui_node.get_node('ImpactVelocity')


func _input(event):

	# Get forward move scale, this is used to create a wished direction for the player
	forwards_move = Input.get_action_strength("move_forward") * FORWARD_SPEED - Input.get_action_strength("move_backwards") * BACK_SPEED
	# Get sideways move scale, this is also a factor for the wished direction
	sideways_move = (Input.get_action_strength("strafe_right") - Input.get_action_strength("strafe_left")) * SIDEWAYS_SPEED

	# Set max current speed
	max_move_speed = MAX_SPEED
	if Input.is_action_pressed("walk"):
		max_move_speed = WALK_SPEED

	# Handle the jump button, the !jump_pressed allows the player to queue the jump like in quake
	if Input.is_action_just_pressed("jump") and !jump_pressed:
		jump_pressed = true
	elif Input.is_action_just_released("jump"):
		jump_pressed = false


	if Input.is_action_pressed("crouch"):
		is_crouching = true
	else:
		is_crouching = false


	if Input.is_action_just_pressed("dev_reset"):
		position = Vector3.ZERO


func _physics_process(delta):

	# Check in which movement state are we
	movement_state()

	# Handle jump movement
	movement_jump(delta)

	# Handle Crouch
	crouch(delta)

	# Handle directional movement
	if state == GROUNDED:
		movement_ground(delta)
		stair_stepping(delta)

	if state == FALLING:
		movement_air(delta)

	# All calculations are done, let godot handle collisions
	move_and_slide()
	
	# If we are in the floor update the normal for the next cycle
	if get_slide_collision_count() > 0:
		ground_normal = get_slide_collision(0).get_normal()

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
	var wish_speed : float = wish_velocity.length()

	if wish_speed > MAX_SPEED:
		wish_velocity *= MAX_SPEED / wish_speed
		wish_speed = MAX_SPEED

	ground_accelerate(wish_direction, wish_speed, delta)
	ground_friction(delta)


func ground_accelerate(wish_direction : Vector3, wish_speed : float, delta : float):
	var current_speed := velocity.dot(wish_direction)

	var add_speed = wish_speed - current_speed
	if add_speed <= 0.0:
		return

	var acceleration_speed = ACCELERATION_RATE * delta * wish_speed
	if acceleration_speed > add_speed:
		acceleration_speed = add_speed
	
	velocity += acceleration_speed * wish_direction


func ground_friction(delta : float):
	
	if velocity.length() < 1.0:
		velocity = Vector3.ZERO

	# TODO: Add more friction on dropoff

	velocity = velocity.lerp(Vector3.ZERO, delta * FRICTION)


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
	var wish_speed = get_wish_velocity().length()
	
	if wish_speed > MAX_AIR_SPEED:
		wish_speed = MAX_AIR_SPEED

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
	pass

# Change velocity while moving up/down sloped ground
func slope_speed(y_normal : float) -> float:
	if y_normal <= 0.97:
		#print('sloped')
		var multiplier = y_normal if velocity.y > 0.0 else 2.0 - y_normal
		return clamp(max_move_speed * multiplier, 5.0, max_move_speed * 1.2)
	return max_move_speed


func get_wish_velocity():
	var wish_velocity : Vector3 = (transform.basis.x * sideways_move - transform.basis.z * forwards_move)
	return wish_velocity


# Function to check and move through steps
func stair_stepping(delta):

	# Get direction in global pos
	var velocity_direction = to_local(global_position + velocity.normalized())
	velocity_direction.y = 0

	# Reset Shape Cast
	test_cast.position = Vector3.ZERO
	test_cast.target_position = Vector3.ZERO


	# Vector to check hor
	var hor_check_vector = velocity_direction * HOR_CHECK_STEP_LENGTH

	# Cast height
	var up_check_vector = VER_CHECK_STEP_LENGTH * Vector3.UP
	test_cast.target_position = up_check_vector
	test_cast.force_shapecast_update()

	# Get the last point before colliding
	var height_point = up_check_vector * test_cast.get_closest_collision_safe_fraction()

	# Reset cast target pos
	test_cast.target_position = Vector3.ZERO

	# Cast Horizontal (from the height point)
	test_cast.position = height_point
	test_cast.target_position = hor_check_vector
	test_cast.force_shapecast_update()

	# Get the last point before colliding horizontally (from the height point)
	var horizontal_point = Vector3(
		hor_check_vector.x * test_cast.get_closest_collision_safe_fraction(),
		height_point.y * test_cast.get_closest_collision_safe_fraction(),
		hor_check_vector.z * test_cast.get_closest_collision_safe_fraction()
	)

	# If we are colliding horizontally, do another cast to check if we can get between the ceiling and the step or floor.
	if test_cast.is_colliding():

		# Get the height diff between pos and ceiling
		var step_diff = -((global_position.y - test_cast.get_collision_point(0).y) + PLAYER_HALF_HEIGHT)
		var hor2_check_pos = Vector3(
			0,
			position.y - (PLAYER_HALF_HEIGHT + step_diff), # Sets Testcast to the height of the step
			0
		)

		# Do another horizontal cast to check if we have space to move
		test_cast.position = hor2_check_pos
		test_cast.target_position = hor_check_vector
		test_cast.force_shapecast_update()

		# if we have the space, we teleport to the step height
		if !test_cast.is_colliding():
			horizontal_point = hor_check_vector
			horizontal_point.y = (position.y - (PLAYER_HALF_HEIGHT +step_diff)) * test_cast.get_closest_collision_safe_fraction()
		else:
			# We don't have space, return and avoid clipping through colliders
			return

	# Cast Down
	var hor_down_check_vector = Vector3(
		0,
		-VER_CHECK_STEP_LENGTH,
		0
	)

	# Cast down from the horizontal check point.
	test_cast.position = horizontal_point
	test_cast.target_position = hor_down_check_vector
	test_cast.force_shapecast_update()

	# Get the position of the possible step next to the player.
	var stair_position =  test_cast.position + (hor_down_check_vector * test_cast.get_closest_collision_safe_fraction())

	# Test movement
	var test_collision = move_and_collide(velocity * delta, true)

	# If we are colliding check if we hit a valid step, and teleport to the step height.
	if test_collision:
		var cast_player_diff = test_cast.global_position - global_position
		var normal = test_collision.get_normal()
		ground_normal = normal
		if abs(normal.y) != 1 and (normal.y == 0 or normal.y > MAX_STAIR_STEP_NORMAL) and stair_position.y < VER_CHECK_STEP_LENGTH:
			position.y = to_global(stair_position).y


func crouch(delta):
	var shape: BoxShape3D = collider.shape
	if is_crouching:
		shape.size.y = CROUCH_HEIGHT
	else:
		shape.size.y = PLAYER_HEIGHT



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
