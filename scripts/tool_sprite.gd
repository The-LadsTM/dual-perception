class_name ToolSprite extends StaticBody3D

const INGREDIENT_LABELS: Dictionary = {
	"milkCarton": "milk",
	"vanillaExtract": "vanilla",
	"saltShaker": "salt",
	"pepperShaker": "pepper",
	"sugarJar": "sugar",
	"flourJar": "flour",
	"bakingPowder": "baking powder",
	"eggCarton": "egg",
}

const OUTLINE_SHADER: Shader = preload("res://shaders/reusable_outline.gdshader")
var highlight_material: ShaderMaterial
var state = "empty"
@export var objectName: String
var bowl: PackedScene = preload("res://prefabs/consumable.tscn")
const HALF = 4;
var hovered
@onready var timer = $Timer
var full: int = 0
var close: bool = true

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D


func _ready() -> void:
	if objectName == "oven":
		sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	highlight_material = ShaderMaterial.new()
	highlight_material.shader = OUTLINE_SHADER
	highlight_material.set_shader_parameter("billboard_enabled", objectName != "oven")
	sprite.material_override = highlight_material
	_update_animation()


func set_hovered(active: bool) -> void:
	if highlight_material != null:
		highlight_material.set_shader_parameter("is_hovered", active)


func _update_animation() -> void:
	if objectName == "mixer":
		var suffix: String = "_Close" if close else "_Open"
		sprite.animation = objectName + ("_Full" if full > HALF else "_Empty") + suffix
	elif objectName == "oven":
		sprite.animation = "oven_Empty_Close" if close else "oven_Empty_Open" 
	elif objectName == "cakePan":
		sprite.animation = objectName + ("_Full" if full > 0 else "_Empty")
		
	if highlight_material != null and sprite.sprite_frames.has_animation(sprite.animation):
		highlight_material.set_shader_parameter("sprite_texture", sprite.sprite_frames.get_frame_texture(sprite.animation, 0))


func set_pour_hover(active: bool) -> void:
	close = not active
	_update_animation()


func pour_ingredient(ingredient: String) -> void:
	if objectName != "mixer" or not INGREDIENT_LABELS.has(ingredient):
		return
	SceneManager.add_to_bowl(ingredient)
	if ingredient == "milkCarton":
		add_to_bowl()
	_show_ingredient_popup("+" + str(INGREDIENT_LABELS[ingredient]))
	_show_pour_effect(ingredient)


func _show_pour_effect(ingredient: String) -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 24
	particles.lifetime = 0.45
	particles.one_shot = true
	particles.explosiveness = 0.1
	particles.direction = Vector3.DOWN
	particles.spread = 8.0
	particles.initial_velocity_min = 0.6
	particles.initial_velocity_max = 0.9
	particles.gravity = Vector3(0, -2.0, 0)
	var drop := SphereMesh.new()
	drop.radius = 0.012
	drop.height = 0.024
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.2, 0.12, 0.07) if ingredient in ["pepperShaker", "vanillaExtract"] else Color(1.0, 0.95, 0.83)
	drop.material = material
	particles.mesh = drop
	add_child(particles)
	particles.global_position = get_pour_position() - Vector3.UP * 0.15
	particles.finished.connect(particles.queue_free)
	particles.emitting = true


func _show_ingredient_popup(text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.outline_size = 10
	label.pixel_size = 0.003
	label.modulate = Color(1.0, 0.92, 0.55)
	label.outline_modulate = Color(0.12, 0.08, 0.03)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
	label.global_position = get_pour_position() + Vector3.UP * 0.25

	var tween := create_tween().bind_node(label).set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 0.45, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.65).set_delay(0.35)
	tween.tween_property(label, "outline_modulate:a", 0.0, 0.65).set_delay(0.35)
	tween.chain().tween_callback(label.queue_free)


func get_pour_position() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var right: Vector3 = camera.global_basis.x if camera != null else Vector3.RIGHT
	return sprite.global_position + right * 0.22 + Vector3.UP * 0.42


func add_to_bowl() -> void:
	full +=1
	_update_animation()

func get_bowl():
	print_debug("you got bow")
	#change mixer art and put bowl in hand
	var bowl_child = bowl.instantiate()
	add_child(bowl_child)
	if full > HALF:
		bowl_child.item = "bowl_Full"
		bowl_child.sprite.animation = "bowl_Full"
	else:
		bowl_child.item = "bowl_Full"
		bowl_child.sprite.animation = "bowl_Full"
	#sprite.animation = 
	return bowl_child

func open(hovered) -> void:
	close = !hovered;
	_update_animation()
