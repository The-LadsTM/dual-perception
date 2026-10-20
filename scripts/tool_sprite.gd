class_name ToolSprite extends StaticBody3D

var state = "empty"
@export var objectName: String
const HALF = 4;
var full = 0
var close = true

@onready var sprite = $AnimatedSprite3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if objectName == "mixer":
		var string;
		if full > HALF:
			string = "_Full"
		else:
			string = "_Empty"
		if close:
			string += "_Close"
		else:
			string += "_Open"
		sprite.animation = objectName+ string
	else:
		if full > 0:
			sprite.animation = objectName + "_Empty"
		else:
			sprite.animation = objectName + "_Full"
	pass

func add_to_bowl():
	full +=1;
