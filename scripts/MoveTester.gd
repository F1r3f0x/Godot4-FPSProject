extends CharacterBody3D

@export var ignore_body: Node

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	if ignore_body:
		add_collision_exception_with(ignore_body)
	pass

func _physics_process(delta):
	pass
