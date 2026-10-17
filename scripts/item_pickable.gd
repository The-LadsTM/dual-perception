class_name Pickable extends RigidBody3D

@export var false_texture: Material
@export var true_texture: Material

@onready var mesh = $MeshInstance3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SceneManager.change_texture.connect(changeTexture)
	mesh.set_surface_override_material(0, false_texture)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func changeTexture(args):
	if args:
		print_debug("true texture")
		mesh.set_surface_override_material(0, true_texture)
	else:
		print_debug("false texture")
		mesh.set_surface_override_material(0, false_texture)
