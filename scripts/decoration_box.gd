class_name DecorationBox
extends StaticBody3D

signal inventory_changed

@export var wall_path: NodePath

var banner_bag: Array[DecorationSlot] = []
var drawn_banners: int = 0
var wall: DecorationWall
var _hovered: bool = false
var _hover_tween: Tween

@onready var hover_label: Label3D = $HoverLabel


func _ready() -> void:
	wall = get_node(wall_path) as DecorationWall
	for slot in wall.slots:
		if slot.kind == "banner":
			banner_bag.append(slot)
	banner_bag.shuffle()
	wall.decoration_placed.connect(func(_item: DecorationItem): inventory_changed.emit())


func draw_item() -> DecorationItem:
	# Balloons are supplied separately by the weight beside this box.
	var slot: DecorationSlot
	if not banner_bag.is_empty():
		slot = banner_bag.pop_back()
		drawn_banners += 1
	else:
		return null
	var item := DecorationItem.new()
	item.setup(slot.kind, slot.item_id, slot.tint)
	add_child(item)
	inventory_changed.emit()
	return item


func set_hovered(active: bool) -> void:
	if _hovered == active:
		return
	_hovered = active
	if _hover_tween != null:
		_hover_tween.kill()
	if active:
		hover_label.show()
	_hover_tween = create_tween().set_parallel(true)
	_hover_tween.tween_property(hover_label, "modulate:a", 1.0 if active else 0.0, 0.15)
	_hover_tween.tween_property(hover_label, "outline_modulate:a", 1.0 if active else 0.0, 0.15)
	if not active:
		_hover_tween.chain().tween_callback(hover_label.hide)
