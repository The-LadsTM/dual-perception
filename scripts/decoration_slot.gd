class_name DecorationSlot
extends Marker3D

@export_enum("banner", "balloon") var kind: String = "banner"
@export var item_id: String = "H"
@export var tint: Color = Color.WHITE
@export_range(0.1, 1.0) var snap_radius: float = 0.38

var occupant: DecorationItem
var tape: Node3D


func _ready() -> void:
	if kind != "banner":
		return
	var tape_random := RandomNumberGenerator.new()
	tape_random.seed = String(name).hash()
	tape = Node3D.new()
	tape.name = "CrossedTape"
	add_child(tape)
	# Tape stays on the wall; each banner marker gets a stable handmade variation.
	tape.position.z = 0.112 - position.z
	tape.rotation.z = -rotation.z + tape_random.randf_range(-0.1, 0.1)
	for angle in [-45.0, 45.0]:
		var strip := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(tape_random.randf_range(0.20, 0.27), tape_random.randf_range(0.045, 0.065), 0.004)
		var material := StandardMaterial3D.new()
		var shade := tape_random.randf_range(-0.035, 0.035)
		material.albedo_color = Color(0.83 + shade, 0.76 + shade, 0.59 + shade, 1.0)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material = material
		strip.mesh = mesh
		strip.rotation.z = deg_to_rad(angle + tape_random.randf_range(-10.0, 10.0))
		strip.position = Vector3(tape_random.randf_range(-0.012, 0.012), tape_random.randf_range(-0.012, 0.012), tape.get_child_count() * 0.001)
		tape.add_child(strip)


func accepts(item: DecorationItem) -> bool:
	return is_instance_valid(item) and not is_instance_valid(occupant) and item.kind == kind and not item.placed


func place(item: DecorationItem) -> bool:
	if not accepts(item):
		return false
	occupant = item
	item.snap_to(self)
	if is_instance_valid(tape):
		tape.hide()
	return true


func take_banner() -> DecorationItem:
	if not is_instance_valid(occupant) or occupant.kind != "banner":
		return null
	var item := occupant
	occupant = null
	item.placed = false
	if is_instance_valid(tape):
		tape.show()
	return item
