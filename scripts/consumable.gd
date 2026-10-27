class_name Consumable extends RigidBody3D

const OUTLINE_SHADER: Shader = preload("res://shaders/reusable_outline.gdshader")
@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var timer: Timer = $Timer
var item: String
var ingredient: String
var held_position: Vector3 = Vector3.ZERO
var pour_angle: float = 0.0
var pouring: bool = false


func pick_up(hand_socket: Marker3D) -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	collision_layer = 0
	collision_mask = 0
	reparent(hand_socket, true)
	transform = Transform3D.IDENTITY
	var height: float = sprite.get_aabb().size.y * absf(sprite.scale.y)
	scale = Vector3.ONE * (0.42 / maxf(height, 0.001))
	held_position = position
	var material := ShaderMaterial.new()
	material.shader = OUTLINE_SHADER
	material.set_shader_parameter("sprite_texture", sprite.sprite_frames.get_frame_texture(sprite.animation, 0))
	sprite.material_override = material


func update_pour_pose(mixer: ToolSprite, delta: float) -> void:
	if pouring:
		return
	var active: bool = is_instance_valid(mixer)
	var target_position: Vector3 = held_position
	if active:
		target_position = get_parent().to_local(mixer.get_pour_position())
	position = position.lerp(target_position, 1.0 - exp(-12.0 * delta))
	# Tilt only after the player clicks to pour.


func add_to_bowl(target: ToolSprite) -> void:
	pouring = true
	var material := sprite.material_override as ShaderMaterial
	var tween := create_tween()
	tween.tween_method(func(angle: float): material.set_shader_parameter("pour_angle", angle), 0.0, deg_to_rad(115.0), 0.18)
	tween.tween_interval(0.2)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.18)
	tween.tween_callback(queue_free)


func _on_timer_timeout() -> void:
	queue_free()
