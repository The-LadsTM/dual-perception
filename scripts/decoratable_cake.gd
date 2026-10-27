class_name DecoratableCake
extends StaticBody3D

@onready var base: Sprite3D = $Base
@onready var bottom: Sprite3D = $BottomFrosting
@onready var top: Sprite3D = $TopFrosting
@onready var ribbon: Sprite3D = $RibbonPiping

var frosted: bool = false
var top_frosted: bool = false
var ribbon_piped: bool = false


func decorate(bag: String) -> void:
	match bag:
		"pipingBag_White":
			frosted = true
			base.texture = preload("res://assets/Sprites/cake_Frosted.png")
			bottom.visible = true
		"pipingBag_Pink":
			top_frosted = true
			top.visible = true
		"pipingBag_Red":
			ribbon_piped = true
			ribbon.visible = true


func get_decoration_position() -> Vector3:
	return global_position + Vector3.UP * 0.65
