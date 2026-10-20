class_name ReusableItem
extends StaticBody3D

const OUTLINE_SHADER: Shader = preload("res://shaders/reusable_outline.gdshader")

@export_range(0.1, 1.0, 0.01) var held_height: float = 0.42

@onready var sprite: Sprite3D = $Sprite3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var home_parent: Node
var home_transform: Transform3D
var original_collision_layer: int
var original_collision_mask: int

var is_held: bool = false


func _ready() -> void:
	home_parent = get_parent()
	home_transform = global_transform

	original_collision_layer = collision_layer
	original_collision_mask = collision_mask

	var mat := sprite.material_override as ShaderMaterial
	if mat != null:
		mat = mat.duplicate() as ShaderMaterial
	else:
		mat = ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	sprite.material_override = mat
	mat.set_shader_parameter("sprite_texture", sprite.texture)
	mat.set_shader_parameter("is_hovered", false)
	sprite.extra_cull_margin = 0.05
	_fit_collision_to_sprite()


func _fit_collision_to_sprite() -> void:
	# Billboards can face any direction, so use the same width on X and Z.
	var bounds: AABB = sprite.get_aabb()
	var visual_size: Vector3 = bounds.size * sprite.scale.abs()
	var shape := BoxShape3D.new()
	shape.size = Vector3(
		maxf(visual_size.x, 0.05),
		maxf(visual_size.y, 0.05),
		maxf(visual_size.x, 0.16)
	)
	collision_shape.shape = shape
	collision_shape.transform = Transform3D(
		Basis.IDENTITY, sprite.transform * bounds.get_center()
	)


func set_hovered(active: bool) -> void:
	var mat := sprite.material_override as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("is_hovered", active and not is_held)


func pick_up(hand_socket: Marker3D) -> void:
	if is_held or not is_instance_valid(hand_socket):
		return

	is_held = true
	set_hovered(false)

	# Prevent raycast and physics collision while held
	collision_layer = 0
	collision_mask = 0

	# Center the sprite at the socket, regardless of its offset above the floor.
	var visual_height: float = sprite.get_aabb().size.y * absf(sprite.scale.y)
	var held_scale: float = held_height / maxf(visual_height, 0.001)
	reparent(hand_socket, true)
	transform = Transform3D(
		Basis.IDENTITY.scaled(Vector3.ONE * held_scale),
		-sprite.position * held_scale
	)


func return_home() -> void:
	if not is_held or not is_instance_valid(home_parent):
		return

	reparent(home_parent, true)
	global_transform = home_transform

	collision_layer = original_collision_layer
	collision_mask = original_collision_mask

	is_held = false
	set_hovered(false)
