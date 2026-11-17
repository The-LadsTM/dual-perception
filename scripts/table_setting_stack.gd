class_name TableSettingStack
extends Node3D

# A stack of identical table-setting items carried in the player's hand.

const HELD_POSITION := Vector3(-0.5, -0.38, -0.2)
const HELD_TILT: float = 1.15 # radians; tips the stack toward the camera so its art reads
const HELD_SCALE: float = 0.55
const STACK_SPACING: float = 0.02
const HOVER_HEIGHT: float = 0.1
const HOVER_SCALE: float = 1.08

var kind: String = ""
var table: DiningTable
var items: Array[TableSettingItem] = []


func setup(item_kind: String, count: int, dining_table: DiningTable) -> void:
	kind = item_kind
	table = dining_table
	name = "%sStack" % item_kind.capitalize()
	# Named kinds (place cards) get one of each name, in a random order.
	var variants := TableSettingItem.variants_for(kind).duplicate()
	variants.shuffle()
	for index in count:
		var item := TableSettingItem.new()
		item.setup(kind, variants[index % variants.size()] if not variants.is_empty() else "")
		add_child(item)
		item.transform = _rest_transform(index)
		items.append(item)


func hold(socket: Marker3D) -> void:
	reparent(socket)
	transform = Transform3D(Basis.from_euler(Vector3(HELD_TILT, 0, 0)).scaled(Vector3.ONE * HELD_SCALE), HELD_POSITION)


func is_empty() -> bool:
	return items.is_empty()


func top() -> TableSettingItem:
	return null if items.is_empty() else items.back()


func pop_top() -> TableSettingItem:
	return null if items.is_empty() else items.pop_back()


# The top item floats over the aimed slot; everything else (and the top item when
# nothing is aimed) eases back to its place in the hand stack.
func update_hover(slot: TableSettingSlot, delta: float) -> void:
	var weight := 1.0 - exp(-12.0 * delta)
	for index in items.size():
		var item := items[index]
		var target := _rest_transform(index)
		if index == items.size() - 1 and is_instance_valid(slot):
			var pose := slot.global_transform * item.layer_transform()
			pose.origin += slot.global_basis.y.normalized() * HOVER_HEIGHT
			pose.basis = pose.basis.orthonormalized().scaled(Vector3.ONE * HOVER_SCALE)
			target = global_transform.affine_inverse() * pose
		item.transform = item.transform.interpolate_with(target, weight)


func _rest_transform(index: int) -> Transform3D:
	return Transform3D(TableSettingItem.hand_basis(kind), Vector3(0, index * STACK_SPACING, 0))
