class_name StaticSprite extends StaticBody3D
@export var objectName: String;
@export var Consumable: PackedScene;
var state = "close"
var close_sprite;
var open_sprite;
@onready var sprite = $Sprite3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	close_sprite = load("res://assets/Sprites/" + objectName + "_Closed.png")
	open_sprite = load("res://assets/Sprites/" + objectName + "_Open.png")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	match state:
		"close":
			sprite.texture = close_sprite
			#print_debug("item is closed")
		"open":
			sprite.texture = open_sprite
			#print_debug("item is open")
		
		
	pass
	
func _input(event: InputEvent) -> void:
	pass

func generate_consumable():
	if Consumable:
		return Consumable;

func _on_mouse_entered() -> void:
	print_debug("selected")
	pass # Replace with function body.
	
func toggle_state():
	if state == "open":
		state = "close"
	else:
		state = "open"
