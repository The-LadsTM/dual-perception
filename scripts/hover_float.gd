extends Node

# Only move visuals: keeping the collision still prevents hover flickering.
@export var lift_height: float = 0.18
@export var bob_height: float = 0.025
@export var bob_speed: float = 2.5

var active: bool = false
var elapsed: float = 0.0
var offset: float = 0.0
var visuals: Array[Node3D] = []
var rest_positions: Array[Vector3] = []


func configure(nodes: Array) -> void:
	for node in nodes:
		visuals.append(node)
		rest_positions.append(node.position)


func set_hovered(value: bool) -> void:
	if value and not active:
		elapsed = 0.0
	active = value


func reset() -> void:
	active = false
	offset = 0.0
	_apply_offset()


func _process(delta: float) -> void:
	elapsed += delta
	var target: float = lift_height + sin(elapsed * bob_speed) * bob_height if active else 0.0
	offset = lerpf(offset, target, 1.0 - exp(-10.0 * delta))
	_apply_offset()


func _apply_offset() -> void:
	for index in range(visuals.size()):
		var visual := visuals[index]
		if is_instance_valid(visual):
			var local_up: Vector3 = visual.get_parent().global_basis.inverse() * Vector3.UP
			visual.position = rest_positions[index] + local_up * offset


func set_rest_position(index: int, value: Vector3) -> void:
	rest_positions[index] = value
	_apply_offset()
