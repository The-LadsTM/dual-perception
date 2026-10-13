class_name StaticSprite extends StaticBody3D
@export var objectName: String;
@export var hasConsumable = true;

@onready var sprite = $Sprite3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	sprite.texture = load("res://assets/Sprites/cake_Decor3.png")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func _input(event: InputEvent) -> void:
	#if event is 
	pass


func _on_mouse_entered() -> void:
	pass # Replace with function body.
