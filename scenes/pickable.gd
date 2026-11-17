extends Node

@onready var raycasting: RayCast3D = $"../Head/Main_Camera/RayCast3D"
@onready var hand: Node3D = $"../Head/Hand"

var holding: RigidBody3D = null
var original_collision_layer: int
var original_freeze: bool
var raycast_receiver;


func _process(_delta: float) -> void:
	if holding != null:
		holding.global_transform = hand.global_transform


func try_interact() -> bool:
	# The player owns the shared interact input and asks this controller first.
	# Dropping a held object keeps the original one-click behavior.
	if holding != null:
		drop_object()
		return true

	return pick_up_object()


func get_pickup_target() -> RigidBody3D:
	if not raycasting.is_colliding():
		return null
	var object := raycasting.get_collider() as RigidBody3D
	if object != null and object.is_in_group("pickable"):
		return object
	return null


func pick_up_object() -> bool:
	var target := get_pickup_target()
	if target == null:
		return false
	holding = target

	# Save the object's original state so it can be restored when dropped
	original_collision_layer = holding.collision_layer
	original_freeze = holding.freeze

	holding.linear_velocity = Vector3.ZERO
	holding.angular_velocity = Vector3.ZERO
	holding.freeze = true
	holding.collision_layer = 2
	return true


func drop_object() -> void:
	# Restore the object's original physics state
	holding.collision_layer = original_collision_layer
	holding.freeze = original_freeze
	holding.linear_velocity = Vector3.ZERO
	holding = null
