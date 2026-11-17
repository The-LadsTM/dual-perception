extends Sprite3D
var random_rotation


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	rotation[1] = randf() * TAU
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func rotate_runner():
	rotation[1] += 3
