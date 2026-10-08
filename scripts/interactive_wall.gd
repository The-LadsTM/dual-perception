class_name InteractiveWall extends StaticBody3D

@export var wall_material: Material

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var player_lock_point: Marker3D = $PlayerLockPoint


func _ready() -> void:
	if wall_material != null:
		mesh_instance.material_override = wall_material


func get_player_lock_position() -> Vector3:
	return player_lock_point.global_position
