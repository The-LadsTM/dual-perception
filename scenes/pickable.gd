extends Node

@onready var raycasting: RayCast3D = $"../Head/Main_Camera/RayCast3D"
@onready var hand: Node3D = $"../Head/Hand"

var holding: RigidBody3D = null
var original_collision_layer: int
var original_freeze: bool


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


func pick_up_object() -> bool:
	if not raycasting.is_colliding():
		return false

	var object = raycasting.get_collider()

	if object is RigidBody3D and object.is_in_group("pickable"):
		holding = object

		# Save the object's original state so it can be restored when dropped
		original_collision_layer = holding.collision_layer
		original_freeze = holding.freeze

		holding.linear_velocity = Vector3.ZERO
		holding.angular_velocity = Vector3.ZERO
		holding.freeze = true
		holding.collision_layer = 2
		return true

	return false


func drop_object() -> void:
	# Restore the object's original physics state
	holding.collision_layer = original_collision_layer
	holding.freeze = original_freeze
	holding.linear_velocity = Vector3.ZERO
	holding = null
