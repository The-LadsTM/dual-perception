class_name ChinaCabinet
extends StaticBody3D

# Invisible collider over the house model's china cabinet. One click hands the
# player a full stack (one item per place setting) of the next layer, in
# TableSettingItem.KIND_ORDER. The next layer unlocks once the previous one is
# fully set on the table.

signal stock_changed

@export var table_path: NodePath

var table: DiningTable
var taken: Dictionary = {}
var _hovered: bool = false
var _hover_tween: Tween

@onready var hover_label: Label3D = $HoverLabel


func _ready() -> void:
	table = get_node(table_path) as DiningTable
	hover_label.hide()
	hover_label.modulate.a = 0.0
	hover_label.outline_modulate.a = 0.0


func next_kind() -> String:
	for kind in TableSettingItem.KIND_ORDER:
		if not taken.get(kind, false):
			return kind
	return ""


func can_take() -> bool:
	var kind := next_kind()
	if kind.is_empty() or not is_instance_valid(table):
		return false
	var index := TableSettingItem.KIND_ORDER.find(kind)
	return index == 0 or table.is_kind_complete(TableSettingItem.KIND_ORDER[index - 1])


func take_stack() -> TableSettingStack:
	if not can_take():
		return null
	var kind := next_kind()
	taken[kind] = true
	var stack := TableSettingStack.new()
	add_child(stack)
	stack.setup(kind, table.slots.size(), table)
	stock_changed.emit()
	return stack


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

