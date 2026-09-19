extends Node

@onready var raycasting = $"../Head/Main_Camera/RayCast3D"
@onready var hand = $"../Head/Hand"
@onready var holding = null;


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var object = raycasting.get_collider()
	if raycasting.is_colliding():
		if object.is_in_group("pickable"):
			if Input.is_action_pressed("interact"):
				if holding:
					holding.linear_velocity = Vector3(0.1, 3, 0.1)
				holding = object;
		#elif Input.is_action_pressed("interact"):
			#
			#holding.linear_velocity = Vector3(0.1, 3, 0.1);
			#holding = null
	
	if holding != null:
		holding.global_position = hand.global_position
		holding.global_rotation = hand.global_rotation
		holding.collision_layer = 2
		#object.linear_velocity = Vector3(0.1, 3, 0.1)
