extends CharacterBody3D

# UI node to draw debug stuff
@export var ui_node: Control

# Movement const variables
@export var MAX_SPEED : float = 10.0        # default: 32.0
@export var WALK_SPEED : float = 16.0       # default: 16.0
@export var STOP_SPEED : float = 10.0       # default: 10.0
@export var GRAVITY : float = 25        # default: 80.0
@export var ACCELERATE : float = 5.0      # default: 10.0
@export var AIR_ACCELERATE : float = 0.35   # default: 0.7
@export var MOVE_FRICTION : float = 8.0     # default: 6.0
@export var JUMP_FORCE : float = 8.0       # default: 27.0
@export var AIR_CONTROL : float = 0.9       # default: 0.9
@export var STEP_SIZE : float = 1.8         # default: 1.8
@export var MAX_HANG : float = 0.2          # defualt: 0.2
	
# Crouch const variables
@export var PLAYER_HEIGHT : float = 3.6    # default: 3.6
@export var CROUCH_HEIGHT : float = 2.0    # default: 2.0

# Camera variables
@export var MOUSE_SENSITIVITY := 0.0009

# State variables
var move_speed: float = 0.0
var forwards_move : float = 0.0
var sideways_move : float = 0.0
var ground_normal : Vector3 = Vector3.UP
var hang_time: float = 0.0
var impact_velocity : float = 0.0

var jump_pressed: bool = false

enum {GROUNDED, FALLING, NOCLIP}
var state := GROUNDED

@onready var head = $Head
@onready var camera = $Head/Camera

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var speed_label : Label
var ups_label : Label

func _ready():
	# Capture mouse in game window
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	
	if ui_node != null:
		speed_label = ui_node.get_node('Velocity')
		ups_label = ui_node.get_node('UPS')
	
	
func _input(event):
	# Handle Mouse input
	if event is InputEventMouseMotion:
		# Rotate BODY horizontally, use the relative mouse movement
		rotation.y -= event.relative.x * MOUSE_SENSITIVITY
		# Rotate camera verticaly, use the relative mouse movement
		camera.rotation.x -= event.relative.y * MOUSE_SENSITIVITY
		# Clamp the vertical rotation to 90°, rotation uses radians
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
	
	forwards_move = Input.get_action_strength("move_forward") - Input.get_action_strength("move_backwards")
	sideways_move = Input.get_action_strength("strafe_right") - Input.get_action_strength("strafe_left")
	
	move_speed = MAX_SPEED # TODO: implement walk speed
		
	# TODO: handle jump and crouch
	if Input.is_action_just_pressed("jump") and !jump_pressed:
		jump_pressed = true
	elif Input.is_action_just_released("jump"):
		jump_pressed = false
		
		
func _physics_process(delta):
	
	movement_state()
	movement_jump(delta)
	if state == GROUNDED:
		movement_ground(delta)
	if state == FALLING:
		movement_air(delta)
	move_and_slide()
	update_ui()

func movement_state():
	
	"""
	var down  : Vector3
	var trace : Trace
	# Check for ground 0.1 units below the player
	down = global_transform.origin + Vector3.DOWN * 0.1
	trace = Trace.new()
	trace.standard(global_transform.origin, down, collider.shape, self)
	"""
	
	if is_on_floor():
		state = GROUNDED
	else:
		state = FALLING
	

func movement_jump(delta):
		# TODO: if is dead return
		
		# Allow jump for a few frames if just ran off platform
		if state != FALLING:
			hang_time = MAX_HANG
		else:
			hang_time -= delta if hang_time > 0.0 else 0.0
		
		# Moving up too fast, don't jump. TODO: check this
		if velocity.y > 54.0: 
			return
			
		if hang_time > 0.0 and jump_pressed:
			state = FALLING
			jump_pressed = false
			hang_time = 0.0
			
			$AudioPlayer3D.play()
			
			# Make sure jump velocity is positive if moving down
			if state == FALLING or velocity.y < 0.0:
				velocity.y = JUMP_FORCE
			else:
				velocity.y += JUMP_FORCE
		
		


func movement_ground(delta):
	var wish_direction : Vector3 = (transform.basis.x * sideways_move + -transform.basis.z * forwards_move)
	wish_direction = wish_direction.normalized()
	wish_direction.slide(ground_normal)
	
	ground_accelerate(wish_direction, slope_speed(ground_normal.y), delta)


func movement_air(delta):
	var wish_direction : Vector3 = (transform.basis.x * sideways_move + -transform.basis.z * forwards_move)
	wish_direction = wish_direction.normalized()
	wish_direction.slide(ground_normal)
	
	var acceleration : float
	if velocity.dot(wish_direction) < 0:
		acceleration = STOP_SPEED
	else:
		acceleration = AIR_ACCELERATE
	air_accelerate(wish_direction, acceleration, delta)
	
	# Air Control
	if state == FALLING:
		if AIR_CONTROL > 0.0:
			air_control(wish_direction, delta)
	
	# Add gravity
	velocity.y -= GRAVITY * delta
	
	# TODO: jump position cache
	
	impact_velocity = abs(int(round(velocity.y)))
	
	
func ground_accelerate(wish_direction : Vector3, wish_speed : float, delta : float):
	var friction : float = MOVE_FRICTION
	if wish_direction != Vector3.ZERO:
		velocity = velocity.lerp(wish_direction * wish_speed, ACCELERATE * delta)
	else:
		velocity = velocity.lerp(Vector3.ZERO, friction * delta)
		
	

func air_accelerate(wish_direction : Vector3, acceleration : float, delta : float):
	var wish_speed := slope_speed(ground_normal.y)
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
	
	velocity[0] *= speed
	velocity[1] = original_y
	velocity[2] *= speed

# Change velocity while moving up/down sloped ground
func slope_speed(y_normal : float) -> float:
	if y_normal <= 0.97:
		var multiplier = y_normal if velocity[1] > 0.0 else 2.0 - y_normal
		return clamp(move_speed * multiplier, 5.0, move_speed * 1.2)
	return move_speed
	
func get_wish_direction():
	var wish_direction : Vector3 = (transform.basis.x * sideways_move + -transform.basis.z * forwards_move)
	wish_direction = wish_direction.normalized()
	
	return wish_direction


# Placeholder code to update debug ui
func update_ui():
	if ui_node == null:
		return
	
	# Update speed label
	speed_label.text = 'Velocity: %s' % velocity
	
	# Update current speed
	var current_speed = velocity.dot(get_wish_direction())
	ups_label.text = 'Current Speed: %s' % current_speed
	
