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
@onready var sprite = $Sprite3D

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
	
	var mat := sprite.material_override as ShaderMaterial
	if mat != null:
		mat = mat.duplicate() as ShaderMaterial
	else:
		mat = ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	sprite.material_override = mat
	mat.set_shader_parameter("sprite_texture", sprite.texture)
	mat.set_shader_parameter("is_hovered", false)
	sprite.extra_cull_margin = 0.05
	#_fit_collision_to_sprite()



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if get_hovered:
		state = "open"
	else:
		state = "close"
	match state:
		"close":
			if random_item != true_item and !reveal:
				sprite.texture = close_false
			else:
				sprite.texture = close_true
			#print_debug("item is closed")
		"open":
			if random_item != true_item and !reveal:
				sprite.texture = open_false
			else:
				sprite.texture = open_true
			#print_debug("item is open")
	
func _input(event: InputEvent) -> void:
	pass

func generate_consumable():
	if Consumable:
		var new_item = Consumable.instantiate()
		add_child(new_item)
		if random_item == "eggCarton":
			new_item.sprite.animation = "egg"
		else:
			new_item.sprite.animation = "scoop"
		return new_item;

func _on_mouse_entered() -> void:
	print_debug("selected")
	pass # Replace with function body.

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
