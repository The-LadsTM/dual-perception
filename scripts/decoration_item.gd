class_name DecorationItem
extends Node3D

var kind: String = "banner"
var item_id: String = ""
var tint: Color = Color.WHITE
var placed: bool = false

const HELD_POSITION := Vector3(-0.52, -0.3, -0.15)
const HELD_SCALE: float = 0.75
const HOVER_SCALE: float = 1.08
const HOVER_DISTANCE: float = 0.06


func setup(category: String, id: String, color: Color = Color.WHITE) -> void:
	kind = category
	item_id = id
	tint = color
	if kind == "banner":
		var sprite := Sprite3D.new()
		sprite.texture = load("res://assets/Sprites/pennon_%s.png" % item_id)
		sprite.pixel_size = 0.0035
		sprite.shaded = false
		add_child(sprite)


func hold(socket: Marker3D) -> void:
	reparent(socket)
	transform = Transform3D.IDENTITY
	position = HELD_POSITION
	scale = Vector3.ONE * HELD_SCALE


func update_hover_pose(slot: Marker3D, delta: float) -> void:
	var target := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * HELD_SCALE), HELD_POSITION)
	if is_instance_valid(slot):
		var floating_pose := slot.global_transform
		floating_pose.origin += slot.global_basis.z.normalized() * HOVER_DISTANCE
		floating_pose.basis = floating_pose.basis.scaled(Vector3.ONE * HOVER_SCALE)
		update_hover_transform(floating_pose, delta)
		return
	transform = transform.interpolate_with(target, 1.0 - exp(-12.0 * delta))


func update_hover_transform(floating_pose: Transform3D, delta: float) -> void:
	var target: Transform3D = (get_parent() as Node3D).global_transform.affine_inverse() * floating_pose
	# Match the kitchen item's exponential lerp, including returning to the hand.
	transform = transform.interpolate_with(target, 1.0 - exp(-12.0 * delta))


func snap_to(slot: Marker3D) -> void:
	reparent(slot)
	transform = Transform3D.IDENTITY
	placed = true
