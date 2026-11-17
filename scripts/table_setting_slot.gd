class_name TableSettingSlot
extends Marker3D

# One place setting on the dining table. Invisible; the marker's +Z points toward the diner.

var layers: Dictionary = {}


func has_kind(kind: String) -> bool:
	return layers.has(kind) and is_instance_valid(layers[kind])


func accepts(kind: String) -> bool:
	var index := TableSettingItem.KIND_ORDER.find(kind)
	if index < 0 or has_kind(kind):
		return false
	# Plates need a charger underneath, and so on up the stack.
	for lower in index:
		if not has_kind(TableSettingItem.KIND_ORDER[lower]):
			return false
	return true


func place(item: TableSettingItem) -> bool:
	if not is_instance_valid(item) or not accepts(item.kind):
		return false
	layers[item.kind] = item
	item.placed = true
	var resting := item.layer_transform()
	# Some pieces join another one (the place card clips into its stand) and
	# from then on move as a single item.
	var mount_kind: String = TableSettingItem.KINDS[item.kind].get("mount_on", "")
	if not mount_kind.is_empty() and has_kind(mount_kind):
		var mount: TableSettingItem = layers[mount_kind]
		item.reparent(mount, true)
		# Use the stand's resting pose, not its current one, in case it is still settling.
		resting = mount.layer_transform().affine_inverse() * resting
	else:
		item.reparent(self, true)
	if TableSettingItem.is_card(item.kind):
		item.add_click_body()
	# Settle from the floating hover pose onto the table.
	var tween := create_tween()
	tween.tween_property(item, "transform", resting, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return true
