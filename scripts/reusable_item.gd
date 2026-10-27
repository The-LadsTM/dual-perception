class_name ReusableItem
extends StaticBody3D

const HOVER_FLOAT = preload("res://scripts/hover_float.gd")
var hover_float: Node

const OUTLINE_SHADER: Shader = preload("res://shaders/reusable_outline.gdshader")

@export_range(0.1, 1.0, 0.01) var held_height: float = 0.42

@export var true_item: String;

@onready var sprite: Sprite3D = $Sprite3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var home_parent: Node
var home_transform: Transform3D
var original_collision_layer: int
var original_collision_mask: int

const POURABLE_ITEMS: Array[String] = ["milkCarton", "pepperShaker", "saltShaker", "vanillaExtract"]
const PIPING_BAGS: Array[String] = ["pipingBag_White", "pipingBag_Pink", "pipingBag_Red"]
var is_held: bool = false
var held_position: Vector3
var pour_angle: float = 0.0
var pour_time_left: float = 0.0


func can_pour() -> bool:
	return true_item in POURABLE_ITEMS


func is_piping_bag() -> bool:
	return true_item in PIPING_BAGS


func update_pour_pose(mixer: ToolSprite, delta: float) -> void:
	var active: bool = is_instance_valid(mixer) and can_pour()
	update_use_pose(active, mixer.get_pour_position() if active else Vector3.ZERO, delta)


func play_pour() -> void:
	pour_time_left = 0.45


func update_use_pose(active: bool, world_position: Vector3, delta: float) -> void:
	pour_time_left = maxf(pour_time_left - delta, 0.0)
	if not is_held:
		return
	var target_position: Vector3 = held_position
	if active:
		target_position = get_parent().to_local(world_position) - sprite.position * scale
	position = position.lerp(target_position, 1.0 - exp(-12.0 * delta))
	var target_angle: float
	if is_piping_bag():
		# Shader angles are counterclockwise; subtract 70 degrees while decorating.
		target_angle = deg_to_rad(20.0 if active else 90.0)
	else:
		target_angle = deg_to_rad(115.0) if active and pour_time_left > 0.0 else 0.0
	pour_angle = lerpf(pour_angle, target_angle, 1.0 - exp(-12.0 * delta))
	(sprite.material_override as ShaderMaterial).set_shader_parameter("pour_angle", pour_angle)



func _ready() -> void:
	hover_float = HOVER_FLOAT.new()
	add_child(hover_float)
	hover_float.configure([sprite])

	home_parent = get_parent()
	home_transform = global_transform

	original_collision_layer = collision_layer
	original_collision_mask = collision_mask
	
	if not true_item.is_empty():
		sprite.texture = load("res://assets/Sprites/" + true_item + ".png")

	var mat := sprite.material_override as ShaderMaterial
	if mat != null:
		mat = mat.duplicate() as ShaderMaterial
	else:
		mat = ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	sprite.material_override = mat
	mat.set_shader_parameter("sprite_texture", sprite.texture)
	mat.set_shader_parameter("is_hovered", false)
	pour_angle = deg_to_rad(90.0) if is_piping_bag() else 0.0
	mat.set_shader_parameter("pour_angle", pour_angle)
	sprite.extra_cull_margin = 0.05
	_fit_collision_to_sprite()
	
	


func _fit_collision_to_sprite() -> void:
	# Billboards can face any direction, so use the same width on X and Z.
	var bounds: AABB = sprite.get_aabb()
	var visual_size: Vector3 = bounds.size * sprite.scale.abs()
	if is_piping_bag():
		visual_size = Vector3(visual_size.y, visual_size.x, visual_size.z)
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
	hover_float.set_hovered(active and not is_held and (can_pour() or is_piping_bag()))
	var mat := sprite.material_override as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("is_hovered", active and not is_held)


func pick_up(hand_socket: Marker3D) -> void:
	if is_held or not is_instance_valid(hand_socket):
		return

	is_held = true
	set_hovered(false)
	hover_float.reset()

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

	held_position = position


func return_home() -> void:
	if not is_held or not is_instance_valid(home_parent):
		return

	pour_time_left = 0.0
	pour_angle = deg_to_rad(90.0) if is_piping_bag() else 0.0
	(sprite.material_override as ShaderMaterial).set_shader_parameter("pour_angle", pour_angle)
	reparent(home_parent, true)
	global_transform = home_transform

	collision_layer = original_collision_layer
	collision_mask = original_collision_mask

	is_held = false
	set_hovered(false)
