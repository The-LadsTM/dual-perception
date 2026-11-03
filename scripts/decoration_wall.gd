class_name DecorationWall
extends InteractiveWall

signal decoration_placed(item: DecorationItem)
signal decoration_removed(item: DecorationItem)
signal completed

@export var look_yaw_limit_degrees: float = 60.0
@export var look_pitch_limit_degrees: float = 40.0
@export var balloon_target_count: int = 10

var slots: Array[DecorationSlot] = []
var placed_count: int = 0
var attached_balloons: Array[PartyBalloon] = []


func _ready() -> void:
	super()
	for child in $BannerSlots.get_children():
		if child is DecorationSlot:
			slots.append(child)


func find_slot(item: DecorationItem, hit_position: Vector3) -> DecorationSlot:
	var nearest: DecorationSlot = null
	var nearest_distance: float = INF
	for slot in slots:
		if not slot.accepts(item):
			continue
		# Ignore depth: the ray hits the wall just behind the marker plane.
		var offset: Vector3 = to_local(hit_position) - to_local(slot.global_position)
		var distance := Vector2(offset.x, offset.y).length()
		if distance <= slot.snap_radius and distance < nearest_distance:
			nearest = slot
			nearest_distance = distance
	return nearest


func try_place(item: DecorationItem, hit_position: Vector3) -> bool:
	var slot := find_slot(item, hit_position)
	if slot == null or not slot.place(item):
		return false
	placed_count += 1
	decoration_placed.emit(item)
	if placed_count == slots.size() + balloon_target_count:
		completed.emit()
	return true


func balloon_pose_at(hit_position: Vector3, floating: bool = false) -> Transform3D:
	var pose := Transform3D(global_basis.orthonormalized(), hit_position + global_basis.z.normalized() * 0.045)
	if floating:
		pose.origin += global_basis.z.normalized() * DecorationItem.HOVER_DISTANCE
		pose.basis = pose.basis.scaled(Vector3.ONE * DecorationItem.HOVER_SCALE)
	return pose


func try_place_balloon(balloon: PartyBalloon, hit_position: Vector3) -> bool:
	if balloon.state != PartyBalloon.State.INFLATED or balloon.placed:
		return false
	# Any point on the front of the wall is valid; no balloon markers or grid.
	var local_hit := to_local(hit_position)
	var shape := $CollisionShape3D.shape as BoxShape3D
	var half_size := shape.size * 0.5
	if absf(local_hit.x) > half_size.x or absf(local_hit.y) > half_size.y or absf(local_hit.z - half_size.z) > 0.02:
		return false
	balloon.attach_to_wall(self, balloon_pose_at(hit_position))
	attached_balloons.append(balloon)
	placed_count += 1
	decoration_placed.emit(balloon)
	if placed_count == slots.size() + balloon_target_count:
		completed.emit()
	return true


func take_banner_at(hit_position: Vector3) -> DecorationItem:
	var nearest: DecorationSlot = null
	var nearest_distance: float = INF
	for slot in slots:
		if slot.kind != "banner" or not is_instance_valid(slot.occupant):
			continue
		var offset: Vector3 = to_local(hit_position) - to_local(slot.global_position)
		var distance := Vector2(offset.x, offset.y).length()
		if distance <= slot.snap_radius and distance < nearest_distance:
			nearest = slot
			nearest_distance = distance
	if nearest == null:
		return null
	var item := nearest.take_banner()
	if item != null:
		placed_count -= 1
		decoration_removed.emit(item)
	return item
