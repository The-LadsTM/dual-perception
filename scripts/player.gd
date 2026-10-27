
class_name Player
extends CharacterBody3D

@export var look_sensitivity = 0.005
@export var speed: float = 5.0
@export var fall_acceleration = 75
@export var acceleration = 60.0
@export var jump_control = 4.5
@export var air_control = 5.0
@export var air_resistance = 2.0
@export var wall_yaw_limit_degrees: float = 12.0
@export var wall_pitch_limit_degrees: float = 10.0

var input_direction: Vector2
var retake = true
var inventory

# Interactive Wall
var active_wall: InteractiveWall = null
var wall_lock_position: Vector3
var wall_look_base_yaw: float
var wall_look_base_pitch: float
var wall_look_yaw_offset: float = 0.0
var wall_look_pitch_offset: float = 0.0

# Reusable Items
var held_reusable_item: ReusableItem = null
var hovered_reusable_item: ReusableItem = null

# Static Sprite
var hovered_static_sprite: StaticSprite = null
var held_consumable: Consumable = null

# Static Sprite
var hovered_tool_sprite: ToolSprite = null
var held_tool: ToolSprite = null

var hovered_recipe_tin: RecipeTin = null
var active_recipe_tin: RecipeTin = null
var _mouse_mode_before_recipe: Input.MouseMode = Input.MOUSE_MODE_CAPTURED

# Nodes
@onready var head = $Head
@onready var camera = $Head/Main_Camera
@onready var interaction_raycast: RayCast3D = $Head/Main_Camera/RayCast3D
@onready var hand_socket: Marker3D = $Head/Main_Camera/HandSocket
@onready var recipe_card_view: RecipeCardView = $RecipeCardView

@onready var photo = $Head/Photo_Camera
@onready var pickup_controller = $pickup_script
@onready var cooldown = SceneManager.get_node("CameraCooldown")
@onready var photo_taken = $TakePhoto


# ==================================================
# READY
# ==================================================

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.make_current()
	interaction_raycast.add_exception(self)
	recipe_card_view.closed.connect(_on_recipe_card_closed)


# ==================================================
# INPUT
# ==================================================

func _unhandled_input(event: InputEvent) -> void:
	if recipe_card_view.visible:
		return

	# Mouse Look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:

		if active_wall != null:
			var yaw_limit: float = deg_to_rad(wall_yaw_limit_degrees)
			var pitch_limit: float = deg_to_rad(wall_pitch_limit_degrees)

			wall_look_yaw_offset = clamp(
				wall_look_yaw_offset - event.relative.x * look_sensitivity,
				-yaw_limit,
				yaw_limit
			)

			wall_look_pitch_offset = clamp(
				wall_look_pitch_offset - event.relative.y * look_sensitivity,
				-pitch_limit,
				pitch_limit
			)

			head.rotation.y = wall_look_base_yaw + wall_look_yaw_offset
			camera.rotation.x = wall_look_base_pitch + wall_look_pitch_offset
			photo.rotation.x = camera.rotation.x

		else:
			head.rotate_y(-event.relative.x * look_sensitivity)

			camera.rotate_x(-event.relative.y * look_sensitivity)

			camera.rotation.x = clamp(
				camera.rotation.x,
				deg_to_rad(-80),
				deg_to_rad(80)
			)

			photo.rotation.x = camera.rotation.x

	# Escape
	if event.is_action_pressed("escape"):
		if active_wall != null:
			exit_wall_interaction()

		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Capture Mouse
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Wall Interaction
	if event.is_action_pressed("wall_interact"):
		handle_wall_interact()
		get_viewport().set_input_as_handled()

	# Item Interaction
	elif event.is_action_pressed("interact"):

		if active_wall == null:

			if not try_interact_recipe() and not try_interact_tool() and not try_interact_static() and not try_interact_reusable():

				# Fall back to existing pickup system
				pickup_controller.try_interact()

		get_viewport().set_input_as_handled()


# ==================================================
# PHYSICS / MOVEMENT
# ==================================================

func _physics_process(delta: float) -> void:
	if recipe_card_view.visible:
		velocity = Vector3.ZERO
		if not is_instance_valid(active_recipe_tin):
			recipe_card_view.close_card()
		return

	# Update reusable item hover
	update_reusable_hover()
	update_recipe_hover()
	update_static_hover()
	update_tool_hover()

	# Wall interaction movement lock
	if active_wall != null:
		if not is_instance_valid(active_wall):
			active_wall = null
		else:
			global_position = wall_lock_position
			velocity = Vector3.ZERO
			return

	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Movement Input
	input_direction = Input.get_vector(
		"left",
		"right",
		"up",
		"down"
	)

	var direction = (
		head.transform.basis *
		Vector3(input_direction.x, 0, input_direction.y)
	).normalized()

	var target_velocity = direction * speed

	var horizontal_velocity = Vector3(
		velocity.x,
		0,
		velocity.z
	)

	if is_on_floor():
		horizontal_velocity = horizontal_velocity.move_toward(
			target_velocity,
			acceleration * delta
		)

		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z

	else:
		if direction:
			horizontal_velocity = horizontal_velocity.move_toward(
				target_velocity,
				air_control * delta
			)

		horizontal_velocity = horizontal_velocity.move_toward(
			Vector3.ZERO,
			air_resistance * delta
		)

		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z

	move_and_slide()

# ==================================================
# TOOL INTERACTION
# ==================================================
func try_interact_tool() -> bool:
	interaction_raycast.force_raycast_update()

	var target := interaction_raycast.get_collider() as ToolSprite

	# Looking at a reusable item
	if target != null:
		# The legacy physics pickup and reusable items share one pair of hands.
		if is_instance_valid(pickup_controller.holding):
			pickup_controller.drop_object()
		
		# If already holding reusable, return it
		if is_instance_valid(held_reusable_item):
			held_reusable_item.add_to_bowl(target)
			target.add_to_bowl()
			SceneManager.add_to_bowl(held_reusable_item.true_item)
		
		# If already holding consumable, destroy it
		if is_instance_valid(held_consumable):
			held_consumable.add_to_bowl(target)
			target.add_to_bowl()
			SceneManager.add_to_bowl(held_consumable.item)
			held_consumable = null
		return true
	return false

# ==================================================
# REUSABLE ITEM INTERACTION
# ==================================================

func try_interact_reusable() -> bool:

	interaction_raycast.force_raycast_update()

	var target := interaction_raycast.get_collider() as ReusableItem

	# Looking at a reusable item
	if target != null:
		# The legacy physics pickup and reusable items share one pair of hands.
		if is_instance_valid(pickup_controller.holding):
			pickup_controller.drop_object()

		# If already holding reusable, return it
		if is_instance_valid(held_reusable_item):
			held_reusable_item.return_home()
			held_reusable_item = null
		
		# If already holding consumable, destroy it
		if is_instance_valid(held_consumable):
			held_consumable.queue_free()
			held_consumable = null

		# Pick up the targeted item
		target.pick_up(hand_socket)
		held_reusable_item = target

		# Clear hover
		if is_instance_valid(hovered_reusable_item):
			hovered_reusable_item.set_hovered(false)

		hovered_reusable_item = null

		return true

	# Click while holding an item
	# Return it to its original position
	if is_instance_valid(held_reusable_item):

		held_reusable_item.return_home()
		held_reusable_item = null

		return true

	# Not a reusable item interaction
	return false
	
	
# ==================================================
# STATIC SPRITE INTERACTION
# ==================================================
func try_interact_static() -> bool:
	interaction_raycast.force_raycast_update()

	var target := interaction_raycast.get_collider() as StaticSprite

	# Looking at a static sprite
	if target != null:
		# The legacy physics pickup and reusable items share one pair of hands.
		if is_instance_valid(pickup_controller.holding):
			pickup_controller.drop_object()

		# If already holding reusable, return it
		if is_instance_valid(held_reusable_item):
			held_reusable_item.return_home()
			held_reusable_item = null
			
		# If already holding consumable, destroy it
		if is_instance_valid(held_consumable):
			held_consumable.queue_free()
			held_consumable = null

		# Pick up the targeted item
		var consumed = target.generate_consumable()
		consumed.pick_up(hand_socket)
		held_consumable = consumed

		return true
	return false

	# Click while holding an item
	# Return it to its original position
	if is_instance_valid(held_reusable_item):

		held_reusable_item.return_home()
		held_reusable_item = null

		return true

	# Not a reusable item interaction
	return false

# ==================================================
# REUSABLE ITEM HOVER
# ==================================================

func update_reusable_hover() -> void:

	var target: ReusableItem = null

	# Don't highlight items during wall interaction
	if active_wall == null and not recipe_card_view.visible:
		interaction_raycast.force_raycast_update()
		if interaction_raycast.is_colliding():
			target = interaction_raycast.get_collider() as ReusableItem

	# Don't repeatedly update the same item
	if target == hovered_reusable_item:
		return

	# Remove highlight from previous item
	if is_instance_valid(hovered_reusable_item):
		hovered_reusable_item.set_hovered(false)

	hovered_reusable_item = target

	# Highlight new item
	if is_instance_valid(hovered_reusable_item):
		hovered_reusable_item.set_hovered(true)

# ==================================================
# STATIC SPRITES HOVER
# ==================================================
func update_static_hover() -> void:
	var target: StaticSprite = null
	if active_wall == null and not recipe_card_view.visible:
		interaction_raycast.force_raycast_update()
		if interaction_raycast.is_colliding():
			target = interaction_raycast.get_collider() as StaticSprite

	# Don't repeatedly update the same item
	if target == hovered_static_sprite:
		return

	# Remove highlight from previous item
	if is_instance_valid(hovered_static_sprite):
		hovered_static_sprite.set_hovered(false)

	hovered_static_sprite = target

	# Highlight new item
	if is_instance_valid(hovered_static_sprite):
		hovered_static_sprite.set_hovered(true)
		
# ==================================================
# TOOL SPRITES HOVER
# ==================================================
func update_tool_hover() -> void:
	var target: ToolSprite = null
	if active_wall == null and not recipe_card_view.visible:
		interaction_raycast.force_raycast_update()
		if interaction_raycast.is_colliding():
			target = interaction_raycast.get_collider() as ToolSprite

	# Don't repeatedly update the same item
	if target == hovered_tool_sprite:
		return

	# Remove highlight from previous item
	if is_instance_valid(hovered_tool_sprite):
		hovered_tool_sprite.set_hovered(false)

	hovered_tool_sprite = target

	# Highlight new item
	if is_instance_valid(hovered_tool_sprite):
		hovered_tool_sprite.set_hovered(true)

# ==================================================
# RECIPE TIN / CARD
# ==================================================

func update_recipe_hover() -> void:
	var target: RecipeTin = null
	if active_wall == null and not recipe_card_view.visible:
		target = interaction_raycast.get_collider() as RecipeTin
	if target == hovered_recipe_tin:
		return
	if is_instance_valid(hovered_recipe_tin):
		hovered_recipe_tin.set_hovered(false)
	hovered_recipe_tin = target
	if is_instance_valid(hovered_recipe_tin):
		hovered_recipe_tin.set_hovered(true)


func try_interact_recipe() -> bool:
	interaction_raycast.force_raycast_update()
	var target := interaction_raycast.get_collider() as RecipeTin
	if target == null:
		return false
	active_recipe_tin = target
	_mouse_mode_before_recipe = Input.mouse_mode
	velocity = Vector3.ZERO
	target.set_open(true)
	recipe_card_view.open_card(target.recipe_title, target.recipe_text, target.card_texture)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	update_reusable_hover()
	update_recipe_hover()
	return true


func _on_recipe_card_closed() -> void:
	if is_instance_valid(active_recipe_tin):
		active_recipe_tin.set_open(false)
	active_recipe_tin = null
	Input.mouse_mode = _mouse_mode_before_recipe


# ==================================================
# INTERACTIVE WALL
# ==================================================

func handle_wall_interact() -> void:

	if active_wall != null:
		exit_wall_interaction()
		return

	interaction_raycast.force_raycast_update()

	if not interaction_raycast.is_colliding():
		return

	var collider = interaction_raycast.get_collider()

	if collider is InteractiveWall:
		enter_wall_interaction(collider)


func enter_wall_interaction(wall: InteractiveWall) -> void:

	active_wall = wall

	var marker_position: Vector3 = wall.get_player_lock_position()

	wall_lock_position = Vector3(
		marker_position.x,
		global_position.y,
		marker_position.z
	)

	global_position = wall_lock_position
	velocity = Vector3.ZERO

	# Face wall center
	var wall_direction: Vector3 = (
		wall.global_position - camera.global_position
	)

	var local_direction: Vector3 = (
		global_transform.basis.inverse() * wall_direction
	)

	var horizontal_distance: float = Vector2(
		local_direction.x,
		local_direction.z
	).length()

	wall_look_base_yaw = atan2(
		-local_direction.x,
		-local_direction.z
	)

	wall_look_base_pitch = clamp(
		atan2(local_direction.y, horizontal_distance),
		deg_to_rad(-80),
		deg_to_rad(80)
	)

	wall_look_yaw_offset = 0.0
	wall_look_pitch_offset = 0.0

	head.rotation.y = wall_look_base_yaw
	camera.rotation.x = wall_look_base_pitch
	photo.rotation.x = wall_look_base_pitch


func exit_wall_interaction() -> void:

	active_wall = null
	velocity = Vector3.ZERO


# ==================================================
# PHOTO SYSTEM
# ==================================================

func _input(event: InputEvent) -> void:
	if recipe_card_view.visible:
		return

	if event.is_action_pressed("photo") and retake:

		var current_camera = get_viewport().get_camera_3d()

		if current_camera == null:
			return

		print_debug(current_camera.name)

		if current_camera.name == camera.name:

			photo.make_current()
			photo_taken.start()

			SceneManager.change_texture.emit(true)


func _on_take_photo_timeout() -> void:

	var picture = get_viewport().get_texture().get_image()

	SceneManager.add_to_gallery(picture)

	cooldown.start()
	retake = false

	camera.make_current()

	SceneManager.change_texture.emit(false)
