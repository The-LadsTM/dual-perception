class_name BalloonSupply
extends StaticBody3D

const HOVER_FLOAT = preload("res://scripts/hover_float.gd")

@export var box_path: NodePath

var variants: Array[int] = [1, 1, 2, 2, 3, 3, 4, 4, 5, 5]
var drawn_count: int = 0
var hover_float: Node
@onready var sprite: Sprite3D = $Sprite3D
@onready var box: DecorationBox = get_node(box_path) as DecorationBox
@onready var pump: BalloonPump = get_node("../BalloonPump") as BalloonPump


func _ready() -> void:
	hover_float = HOVER_FLOAT.new()
	add_child(hover_float)
	hover_float.configure([sprite])
	variants.shuffle()


func set_hovered(active: bool) -> void:
	hover_float.set_hovered(active and not variants.is_empty())


func draw_balloon() -> PartyBalloon:
	if variants.is_empty() or is_instance_valid(pump.occupant):
		return null
	var balloon := PartyBalloon.new()
	balloon.setup_balloon(variants.pop_back())
	add_child(balloon)
	drawn_count += 1
	set_hovered(false)
	return balloon
