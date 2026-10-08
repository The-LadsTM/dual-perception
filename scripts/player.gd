class_name Player extends CharacterBody3D

@export var look_sensitivity = 0.005
@export var speed:float = 5.0
@export var fall_acceleration = 75
@export var acceleration = 60.0
@export var jump_control = 4.5
@export var air_control = 5.0
@export var air_resistance = 2.0
@export var wall_yaw_limit_degrees: float = 12.0
@export var wall_pitch_limit_degrees: float = 10.0

var input_direction: Vector2
var retake = true
var inventory;
var active_wall: InteractiveWall = null
var wall_lock_position: Vector3
var wall_look_base_yaw: float
var wall_look_base_pitch: float
var wall_look_yaw_offset: float = 0.0
var wall_look_pitch_offset: float = 0.0

@onready var head = $Head
@onready var camera = $Head/Main_Camera
@onready var interaction_raycast: RayCast3D = $Head/Main_Camera/RayCast3D
@onready var photo = $Head/Photo_Camera
@onready var pickup_controller = $pickup_script
@onready var cooldown = SceneManager.get_node("CameraCooldown")
@onready var photo_taken = $TakePhoto

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED 

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if active_wall != null:
			var yaw_limit: float = deg_to_rad(wall_yaw_limit_degrees)
			var pitch_limit: float = deg_to_rad(wall_pitch_limit_degrees)
			wall_look_yaw_offset = clamp(wall_look_yaw_offset - event.relative.x * look_sensitivity, -yaw_limit, yaw_limit)
			wall_look_pitch_offset = clamp(wall_look_pitch_offset - event.relative.y * look_sensitivity, -pitch_limit, pitch_limit)
			head.rotation.y = wall_look_base_yaw + wall_look_yaw_offset
			camera.rotation.x = wall_look_base_pitch + wall_look_pitch_offset
			photo.rotation.x = camera.rotation.x
		else:
			head.rotate_y(-event.relative.x * look_sensitivity)
			camera.rotate_x(-event.relative.y * look_sensitivity)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))
			photo.rotation.x = camera.rotation.x
		
	if event.is_action_pressed("escape"):
		if active_wall != null:
			exit_wall_interaction()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event.is_action_pressed("wall_interact"):
		handle_wall_interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		if active_wall == null:
			pickup_controller.try_interact()
		get_viewport().set_input_as_handled()
		
func _physics_process(delta: float) -> void:
	if active_wall != null:
		if not is_instance_valid(active_wall):
			active_wall = null
		else:
			global_position = wall_lock_position
			velocity = Vector3.ZERO
			return

	if not is_on_floor():
		velocity += get_gravity()*delta
	
	#get direction input
	input_direction = Input.get_vector("left", "right", "up", "down")
	var direction = (head.transform.basis * Vector3(input_direction.x, 0, input_direction.y)).normalized()
	
#	calculate movement
	var target_velocity = direction* speed
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	
	if is_on_floor: 
		horizontal_velocity = horizontal_velocity.move_toward(target_velocity, acceleration*delta)
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z
	else:
		if direction:
			horizontal_velocity = horizontal_velocity.move_toward(target_velocity, air_control * delta)
		horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, air_resistance * delta)
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z
	
	move_and_slide()


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
	wall_lock_position = Vector3(marker_position.x, global_position.y, marker_position.z)
	global_position = wall_lock_position
	velocity = Vector3.ZERO

	# Face the wall center, then allow only a small look offset around it.
	var wall_direction: Vector3 = wall.global_position - camera.global_position
	var local_direction: Vector3 = global_transform.basis.inverse() * wall_direction
	var horizontal_distance: float = Vector2(local_direction.x, local_direction.z).length()
	wall_look_base_yaw = atan2(-local_direction.x, -local_direction.z)
	wall_look_base_pitch = clamp(atan2(local_direction.y, horizontal_distance), deg_to_rad(-80), deg_to_rad(80))
	wall_look_yaw_offset = 0.0
	wall_look_pitch_offset = 0.0
	head.rotation.y = wall_look_base_yaw
	camera.rotation.x = wall_look_base_pitch
	photo.rotation.x = wall_look_base_pitch


func exit_wall_interaction() -> void:
	active_wall = null
	velocity = Vector3.ZERO

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("photo") and retake:
		var curr = get_viewport().get_camera_3d().name
		print_debug(get_viewport().get_camera_3d().name)
		if curr == camera.name:
			photo.make_current()
			photo_taken.start()
			SceneManager.change_texture.emit(true);




func _on_take_photo_timeout() -> void:
	var picture = get_viewport().get_texture().get_image()
	SceneManager.add_to_gallery(picture);
	cooldown.start()
	retake = false;
	camera.make_current()
	SceneManager.change_texture.emit(false);
