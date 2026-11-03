class_name PartyBalloon
extends DecorationItem

enum State { DEFLATED, INFLATING, INFLATED, ATTACHED }

# Match the actual art, including the pink fifth variant and green third variant.
const VARIANT_COLORS: Dictionary = {1: "Pink", 2: "Pink", 3: "Green", 4: "Green", 5: "Pink"}
const FOREGROUND_PRIORITY: int = 100

var state: State = State.DEFLATED
var variant: int = 1
var sprite: Sprite3D
var _inflation_tween: Tween


func setup_balloon(number: int) -> void:
	kind = "balloon"
	variant = number
	item_id = str(number)
	sprite = Sprite3D.new()
	sprite.shaded = false
	add_child(sprite)
	var color_name: String = VARIANT_COLORS[variant]
	sprite.texture = load("res://assets/Sprites/balloon_deflated%s.png" % color_name)
	sprite.pixel_size = 0.0028
	sprite.position.y = sprite.texture.get_height() * sprite.pixel_size * 0.5


func update_pump_hover(nozzle: Marker3D, delta: float) -> void:
	var pose := nozzle.global_transform
	pose.origin += nozzle.global_basis.z.normalized() * HOVER_DISTANCE
	pose.basis = (pose.basis * Basis(Vector3.BACK, PI)).scaled(Vector3.ONE * HOVER_SCALE)
	update_hover_transform(pose, delta)


func hand_texture() -> Texture2D:
	# The existing first variant's filename uses "ballon", with one o.
	var path: String = "res://assets/Sprites/ballon_1_hand.png" if variant == 1 else "res://assets/Sprites/balloon_%d_hand.png" % variant
	return load(path) as Texture2D


func inflate() -> void:
	if state != State.DEFLATED:
		return
	state = State.INFLATING
	# Screen-facing sprites remain upright in the pump, hand, and attached poses.
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Keep the balloon and its ribbon/string above transparent pennants and cords.
	sprite.no_depth_test = true
	sprite.render_priority = FOREGROUND_PRIORITY
	sprite.texture = hand_texture()
	sprite.pixel_size = 0.68 / sprite.texture.get_height()
	sprite.position.y = 0.34
	sprite.scale = Vector3.ONE * 0.25
	_inflation_tween = create_tween()
	_inflation_tween.tween_property(sprite, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_inflation_tween.tween_callback(func(): state = State.INFLATED)


func attach_to_wall(wall: Node3D, pose: Transform3D) -> void:
	reparent(wall)
	global_transform = pose
	placed = true
	state = State.ATTACHED
	# Preserve the balloon body's top and size while revealing its hanging string.
	sprite.texture = load("res://assets/Sprites/balloon_%d.png" % variant)
	sprite.position.y = 0.68 - sprite.texture.get_height() * sprite.pixel_size * 0.5
