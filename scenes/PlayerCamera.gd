extends Camera3D

### Camera variables
## Mouse sensitivity scale factor, bigger is slower. Default: 0.009
@export var MOUSE_SENSITIVITY : float = 1000
@export var INTERPOLATION_WEIGHT: float = 0.2
###

@export var player: Node3D


func _ready():
	# Capture mouse in game window
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event):
	# Handle Mouse input
	if event is InputEventMouseMotion:
		# Rotate BODY horizontally, use the relative mouse movement
		player.rotation.y -= event.relative.x * 1/MOUSE_SENSITIVITY
		rotation.y -= event.relative.x * 1/MOUSE_SENSITIVITY
		# Rotate camera verticaly, use the relative mouse movement
		rotation.x -= event.relative.y * 1/MOUSE_SENSITIVITY
		# Clamp the vertical rotation to 90°, rotation uses radians
		rotation.x = clamp(rotation.x, deg_to_rad(-90), deg_to_rad(90))
		

func _process(delta):
	var player_pos_with_offset = Vector3(
		player.position.x,
		player.position.y + 0.6,
		player.position.z
		
	)
	position = lerp(position, player_pos_with_offset, INTERPOLATION_WEIGHT)

