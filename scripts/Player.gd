extends CharacterBody3D

# UI node to draw debug stuff
@export var ui_node: Control

# Movement variables
@export var SPEED := 5.0
@export var MAX_SPEED := 100
@export var JUMP_VELOCITY := 4.5
@export var FRICTION := 1.0
@export var EDGE_FRICTION := 1.0
@export var STOP_SPEED := 1.0
@export var ACCELERATION := 2.0

#var whish_direction: Vector2
#var wish_velocity: Vector3
#var wish_speed := 0.0

# Camera variables
@export var MOUSE_SENSITIVITY := 0.0009

@onready var head = $Head
@onready var camera = $Head/Camera

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var speed_label: Label


func _ready():
	# Capture mouse in game window
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if ui_node != null:
		speed_label = ui_node.get_node('Velocity')
	
	
func _input(event):
	# Handle Mouse input
	if event is InputEventMouseMotion:
		# Rotate BODY horizontally, use the relative mouse movement
		rotation.y -= event.relative.x * MOUSE_SENSITIVITY
		# Rotate camera verticaly, use the relative mouse movement
		camera.rotation.x -= event.relative.y * MOUSE_SENSITIVITY
		# Clamp the vertical rotation to 90°, rotation uses radians
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90) )
		
		
func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("strafe_left", "strafe_right", "move_forward", "move_backwards")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	update_ui()


# Placeholder code to update debug ui
func update_ui():
	if ui_node == null:
		return
	
	# Update speed label
	speed_label.text = 'Velocity: %s' % velocity
	
