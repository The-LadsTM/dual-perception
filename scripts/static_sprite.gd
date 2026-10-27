class_name StaticSprite extends StaticBody3D
@export var true_item: String;
var random_item;
@export var Consumable: PackedScene;
const OUTLINE_SHADER: Shader = preload("res://shaders/reusable_outline.gdshader")
var state = "close"
var close_true;
var open_true;
var close_false;
var open_false;
var get_hovered = false;
var reveal = false;

@export_range(0.1, 1.0, 0.01) var held_height: float = 0.42

@onready var sprite: Sprite3D = $Sprite3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var home_parent: Node
var home_transform: Transform3D
var original_collision_layer: int
var original_collision_mask: int

var is_held: bool = false
var highlight_material: ShaderMaterial
var sprite_bottom: float

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SceneManager.change_texture.connect(changeTexture)
	random_item = SceneManager.get_random_item(true_item);
	print_debug(random_item)

	if random_item != true_item:
		close_false = load("res://assets/Sprites/" + random_item + "_Closed.png")
		open_false = load("res://assets/Sprites/" + random_item + "_Open.png")

	close_true = load("res://assets/Sprites/" + true_item + "_Closed.png")
	open_true = load("res://assets/Sprites/" + true_item + "_Open.png")
	
	home_parent = get_parent()
	home_transform = global_transform

	original_collision_layer = collision_layer
	original_collision_mask = collision_mask
	
	if close_false:
		sprite.texture = close_false
	else:
		sprite.texture = close_true

	sprite_bottom = sprite.position.y - sprite.texture.get_height() * sprite.pixel_size * sprite.scale.y * 0.5
	highlight_material = ShaderMaterial.new()
	highlight_material.shader = OUTLINE_SHADER
	sprite.material_override = highlight_material
	highlight_material.set_shader_parameter("sprite_texture", sprite.texture)
	_fit_collision_to_sprite()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	state = "open" if get_hovered else "close"
	var use_false: bool = random_item != true_item and not reveal and close_false != null
	var texture: Texture2D
	if get_hovered:
		texture = open_false if use_false else open_true
	else:
		texture = close_false if use_false else close_true
	if sprite.texture != texture:
		sprite.texture = texture
		sprite.position.y = sprite_bottom + texture.get_height() * sprite.pixel_size * sprite.scale.y * 0.5
		highlight_material.set_shader_parameter("sprite_texture", texture)



func _fit_collision_to_sprite() -> void:
	# Billboards can face any direction, so use the same width on X and Z.
	var bounds: AABB = sprite.get_aabb()
	var visual_size: Vector3 = bounds.size * sprite.scale.abs()
	var shape := BoxShape3D.new()
	shape.size = Vector3(
		maxf(visual_size.x, 0.05),
		maxf(visual_size.y, 0.05),
		maxf(visual_size.x, 0.16)
	)
	collision_shape.shape = shape
	collision_shape.transform = Transform3D(
		Basis.IDENTITY, sprite.transform * bounds.get_center()
	)

func generate_consumable():
	if Consumable:
		var new_item = Consumable.instantiate()
		add_child(new_item)
		new_item.ingredient = true_item
		match true_item:
			"eggCarton":
				new_item.item = "egg"
				new_item.sprite.animation = "egg"
			"sugarJar":
				new_item.item = "scoop"
				new_item.sprite.animation = "scoop"
			"flourJar":
				new_item.item = "scoop"
				new_item.sprite.animation = "scoop"
			"bakingPowder":
				new_item.item = "teaspoon"
				new_item.sprite.animation = "teaspoon"
		return new_item;

func open():
	if state != "open":
		state = "open"
		
func close():
	if state != "close":
		state = "close"

func changeTexture(args):
	if args:
		print_debug("true texture")
		reveal = true
	else:
		print_debug("false texture")
		reveal = false

func set_hovered(active: bool) -> void:
	get_hovered = active
	if highlight_material != null:
		highlight_material.set_shader_parameter("is_hovered", active)
