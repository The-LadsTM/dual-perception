class_name Player extends CharacterBody3D

@export var look_sensitivity = 0.005
@export var speed:float = 5.0
@export var fall_acceleration = 75
@export var acceleration = 60.0
@export var jump_control = 4.5
@export var air_control = 5.0
@export var air_resistance = 2.0

var input_direction: Vector2
var retake = true

@onready var head = $Head
@onready var camera = $Head/Main_Camera
@onready var photo = $Head/Photo_Camera
@onready var cooldown = SceneManager.get_node("CameraCooldown")
@onready var photo_taken = $TakePhoto

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED 

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		head.rotate_y(-event.relative.x * look_sensitivity)
		camera.rotate_x(-event.relative.y * look_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))
		
	if Input.is_action_just_pressed("escape"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
func _physics_process(delta: float) -> void:

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

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("photo") and retake:
		var curr = get_viewport().get_camera_3d().name
		print_debug(get_viewport().get_camera_3d().name)
		if curr == camera.name:
			photo.make_current()
			photo_taken.start()
			SceneManager.change_texture.emit(true);
			#var picture = get_viewport().get_texture().get_image()
			#SceneManager.add_to_gallery(picture);
			#$CameraCooldown.start()
			#retake = false;
			#camera.make_current()
			#get_viewport().get_texture().get_image().save_png('res://photos/' + get_parent().name)
		#else:
			#camera.make_current()




func _on_take_photo_timeout() -> void:
	var picture = get_viewport().get_texture().get_image()
	SceneManager.add_to_gallery(picture);
	cooldown.start()
	retake = false;
	camera.make_current()
	SceneManager.change_texture.emit(false);
