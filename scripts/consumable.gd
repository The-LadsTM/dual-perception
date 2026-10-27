class_name Consumable extends RigidBody3D

@onready var sprite = $AnimatedSprite3D
var item: String
@onready var timer = $Timer;


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func change_sprite():
	pass

func pick_up(hand_socket: Marker3D) -> void:
	reparent(hand_socket, true)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	position = Vector3.ZERO
	collision_layer = 3

func add_to_bowl(target) -> void:
	sprite.animation = item + "_put"
	timer.start()
	reparent(target, true)
	position = Vector3(-0.2, 0.5, 0)


func _on_timer_timeout() -> void:
	queue_free()
	pass # Replace with function body.
