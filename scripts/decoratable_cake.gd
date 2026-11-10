class_name DecoratableCake
extends StaticBody3D

@onready var base: Sprite3D = $Base
@onready var bottom: Sprite3D = $BottomFrosting
@onready var top: Sprite3D = $TopFrosting
@onready var ribbon: Sprite3D = $RibbonPiping

const OUTLINE_SHADER: Shader = preload("res://shaders/reusable_outline.gdshader")
var highlight_material: ShaderMaterial
var reveal = false


func _ready() -> void:
	SceneManager.change_texture.connect(changeTexture)
	highlight_material = ShaderMaterial.new()
	highlight_material.shader = OUTLINE_SHADER
	highlight_material.set_shader_parameter("sprite_texture", base.texture)
	base.material_override = highlight_material


func set_hovered(active: bool) -> void:
	highlight_material.set_shader_parameter("is_hovered", active)


var frosted: bool = false
var top_frosted: bool = false
var ribbon_piped: bool = false


func decorate(bag: String) -> void:
	
	match bag:
		"pipingBag_White":
			if !base.visible:
				return
			frosted = true
			base.texture = preload("res://assets/Sprites/cake_Frosted.png")
			base.render_priority = 0
			highlight_material.set_shader_parameter("sprite_texture", base.texture)
			bottom.visible = true
		"pipingBag_Pink":
			if !base.visible:
				return
			top_frosted = true
			top.visible = true
		"pipingBag_Red":
			if !base.visible:
				return
			ribbon_piped = true
			ribbon.visible = true
		"cakePan_Baked":
			base.visible = true


func get_decoration_position() -> Vector3:
	return global_position + Vector3.UP * 0.65

func changeTexture(args):
	if args:
		print_debug("true texture")
		reveal = true
	else:
		print_debug("false texture")
		reveal = false
	
