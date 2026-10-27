class_name ToolSprite extends StaticBody3D

const INGREDIENT_LABELS: Dictionary = {
	"milkCarton": "milk",
	"vanillaExtract": "vanilla",
	"saltShaker": "salt",
	"pepperShaker": "pepper",
}

var state = "empty"
@export var objectName: String
const HALF = 4;
var hovered
@onready var timer = $Timer
var full: int = 0
var close: bool = true

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D


func _ready() -> void:
	if objectName == "oven":
		print_debug("oven here")
		sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	pass # Replace with function body.
	_update_animation()


func _update_animation() -> void:
	if objectName == "mixer":
		var suffix: String = "_Close" if close else "_Open"
		sprite.animation = objectName + ("_Full" if full > 0 else "_Empty") + suffix
	elif objectName == "oven":
		var suffix: String = "_Close" if close else "_Open"
		sprite.animation = objectName + ("_Full" if full > 0 else "_Empty") + suffix
	elif objectName == "cakePan":
		sprite.animation = objectName + ("_Full" if full > 0 else "_Empty")
		

func _process(delta: float) -> void:
	if objectName == "oven":
		print_debug(sprite.billboard)
		sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		


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
