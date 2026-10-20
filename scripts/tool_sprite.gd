class_name ToolSprite extends StaticBody3D

var state = "empty"
@export var objectName: String
var full = false
var close = true
@onready var sprite = $AnimatedSprite3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if objectName == "mixer":
		var string;
		if full:
			string = "_Full"
		else:
			string = "_Empty"
		if close:
			string += "_Close"
		else:
			string += "_Open"
		sprite.animation = objectName+ string
	else:
		if full:
			sprite.animation = objectName + "_Empty"
		else:
			sprite.animation = objectName + "_Full"
	pass

func add_to_bowl():
	full = true;
