class_name ToolSprite extends StaticBody3D

var state = "empty"
@export var objectName: String
const HALF = 4;
var full = 0
var hovered
@onready var timer = $Timer

@onready var sprite = $AnimatedSprite3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if objectName == "oven":
		sprite.billboard = 0
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if objectName == "mixer":
		var string;
		if full > HALF:
			string = "_Full"
		else:
			string = "_Empty"
		if !hovered:
			string += "_Close"
		else:
			string += "_Open"
		sprite.animation = objectName + string
		#print_debug(sprite.animation)
	elif objectName == "cakePan":
		if full < 1:
			sprite.animation = objectName + "_Empty"
		else:
			sprite.animation = objectName + "_Full"
	elif objectName == "oven":
		var string;
		if full < 1:
			string = objectName + "_Empty"
		else:
			string = objectName + "_Full"
		if hovered:
			string = string + "_Open"
		else:
			string = string + "_Close"
		sprite.animation = string

func add_to_bowl():
	full +=1;
	print_debug(full)

func set_hovered(active: bool) -> void:
	hovered = active

func get_bowl():
	if objectName != "oven":
		print_debug("you have the mixer")
		return self;
	
func activate():
	timer.start()
