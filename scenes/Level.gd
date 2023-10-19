extends Node3D

var map: QodotMap
var map_collider: StaticBody3D

func _ready():
	map = $Map
	map_collider = $Map/entity_0_worldspawn
	
	$Map/entity_0_worldspawn.set_collision_layer_value(1, false)
	$Map/entity_0_worldspawn.set_collision_layer_value(2, true)
	$Map/entity_0_worldspawn.set_collision_mask_value(1, false)
