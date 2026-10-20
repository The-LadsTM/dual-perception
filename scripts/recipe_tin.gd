class_name RecipeTin
extends StaticBody3D

const OUTLINE_SHADER: Shader = preload("res://shaders/reusable_outline.gdshader")

@export var closed_texture: Texture2D = preload("res://assets/Sprites/recipeTin_Closed.png")
@export var open_texture: Texture2D = preload("res://assets/Sprites/recipeTin_Open.png")
@export var card_texture: Texture2D = preload("res://assets/Sprites/recipeCard_Small.png")
@export var recipe_title: String = ""
@export_multiline var recipe_text: String = ""

var is_open: bool = false
var _sprite_bottom: float
var _material: ShaderMaterial

@onready var sprite: Sprite3D = $Sprite3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = OUTLINE_SHADER
	_material.set_shader_parameter("outline_width", 3.0)
	sprite.material_override = _material
	sprite.extra_cull_margin = 0.05
	_sprite_bottom = sprite.position.y - closed_texture.get_height() * sprite.pixel_size * 0.5
	set_open(false)


func set_hovered(active: bool) -> void:
	_material.set_shader_parameter("is_hovered", active and not is_open)


func set_open(opened: bool) -> void:
	is_open = opened
	sprite.texture = open_texture if opened else closed_texture
	_material.set_shader_parameter("sprite_texture", sprite.texture)
	set_hovered(false)
	# Keep the base of the tin in place when the lid changes the image size.
	var image_size: Vector2 = sprite.texture.get_size() * sprite.pixel_size
	sprite.position.y = _sprite_bottom + image_size.y * 0.5
	var shape := BoxShape3D.new()
	shape.size = Vector3(image_size.x, image_size.y, image_size.x)
	collision_shape.shape = shape
	collision_shape.position = sprite.position
