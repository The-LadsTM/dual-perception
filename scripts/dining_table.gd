class_name DiningTable
extends StaticBody3D

# Invisible collider over the house model's dining tabletop. Place settings are
# TableSettingSlot markers under PlaceSettings.

signal item_placed(slot: TableSettingSlot, item: TableSettingItem)
signal kind_completed(kind: String)
signal completed

# How close (on the tabletop) the ray must pass to where the held item would go
# for it to float there.
@export_range(0.1, 1.5, 0.01) var snap_radius: float = 0.4

var slots: Array[TableSettingSlot] = []


func _ready() -> void:
	for child in $PlaceSettings.get_children():
		if child is TableSettingSlot:
			slots.append(child)


func find_slot(kind: String, point: Vector3) -> TableSettingSlot:
	var best: TableSettingSlot = null
	var best_distance := snap_radius
	for slot in slots:
		if not slot.accepts(kind):
			continue
		# Each kind has its own spot in the setting (fork on the left, glass top-right...).
		var offset := slot.global_transform * TableSettingItem.offset_for(kind) - point
		var distance := Vector2(offset.x, offset.z).length()
		if distance < best_distance:
			best = slot
			best_distance = distance
	return best


func place(slot: TableSettingSlot, item: TableSettingItem) -> bool:
	if not slot in slots or not slot.place(item):
		return false
	item_placed.emit(slot, item)
	if is_kind_complete(item.kind):
		kind_completed.emit(item.kind)
		if item.kind == TableSettingItem.KIND_ORDER.back():
			completed.emit()
	return true


func is_kind_complete(kind: String) -> bool:
	if slots.is_empty():
		return false
	for slot in slots:
		if not slot.has_kind(kind):
			return false
	return true


func count_placed(kind: String) -> int:
	var count := 0
	for slot in slots:
		if slot.has_kind(kind):
			count += 1
	return count
