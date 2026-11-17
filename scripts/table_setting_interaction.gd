extends Node

# Player-side dispatcher for the dining-table setting task: take a stack from the
# china cabinet, then aim at the table to float the top item onto the nearest
# free place setting and click to set it down.

var held_stack: TableSettingStack
var target_slot: TableSettingSlot
var hovered_cabinet: ChinaCabinet

@onready var player: Player = get_parent()


func _physics_process(delta: float) -> void:
	if player.is_card_view_open():
		_set_hovered_cabinet(null)
		return
	var ray := player.interaction_raycast
	ray.force_raycast_update()
	_set_hovered_cabinet(ray.get_collider() as ChinaCabinet)
	target_slot = null
	if not is_holding():
		return
	var table := ray.get_collider() as DiningTable
	if table != null and table == held_stack.table:
		target_slot = table.find_slot(held_stack.kind, ray.get_collision_point())
	held_stack.update_hover(target_slot, delta)


func is_holding() -> bool:
	return is_instance_valid(held_stack)


func is_reticle_target(target: Node3D) -> bool:
	if target is ChinaCabinet:
		return not is_holding() and target.can_take() and _other_hands_empty()
	if target is DiningTable:
		return is_holding() and is_instance_valid(target_slot)
	return _readable_card(target) != null


func handle_input(event: InputEvent) -> bool:
	if not event.is_action("interact"):
		return false
	if event.is_action_released("interact"):
		return is_holding()
	if not event.is_action_pressed("interact"):
		return false
	var ray := player.interaction_raycast
	ray.force_raycast_update()
	if is_holding():
		# While carrying a stack, clicks only ever set items down.
		var table := ray.get_collider() as DiningTable
		if table != null and table == held_stack.table:
			var slot := table.find_slot(held_stack.kind, ray.get_collision_point())
			if slot != null:
				table.place(slot, held_stack.pop_top())
				target_slot = null
				if held_stack.is_empty():
					held_stack.queue_free()
					held_stack = null
		return true
	var card := _readable_card(ray.get_collider())
	if card != null:
		player.velocity = Vector3.ZERO
		player.name_card_view.open_card(card.variant)
		return true
	var cabinet := ray.get_collider() as ChinaCabinet
	if cabinet == null:
		return false
	if not cabinet.can_take() or not _free_hands():
		return true
	held_stack = cabinet.take_stack()
	if is_holding():
		held_stack.hold(player.hand_socket)
	return true


# A place card on the table can be read once every card has been set out,
# with empty hands.
func _readable_card(collider: Object) -> TableSettingItem:
	if is_holding():
		return null
	var card := TableSettingItem.from_collider(collider)
	if card == null or not card.placed:
		return null
	var table := _table_of(card)
	if table == null or not table.is_kind_complete(card.kind):
		return null
	return card


func _table_of(node: Node) -> DiningTable:
	while node != null:
		if node is DiningTable:
			return node
		node = node.get_parent()
	return null


func _set_hovered_cabinet(cabinet: ChinaCabinet) -> void:
	if hovered_cabinet == cabinet:
		return
	if is_instance_valid(hovered_cabinet):
		hovered_cabinet.set_hovered(false)
	hovered_cabinet = cabinet
	if is_instance_valid(hovered_cabinet):
		hovered_cabinet.set_hovered(true)


func _other_hands_empty() -> bool:
	return (
		not is_instance_valid(player.decoration_interaction.held_item)
		and not is_instance_valid(player.held_consumable)
		and not is_instance_valid(player.held_tool)
	)


# Put away what can be put away (reusable items go home, physics pickups drop);
# refuse if the player is carrying something that can't simply be set aside.
func _free_hands() -> bool:
	if not _other_hands_empty():
		return false
	if is_instance_valid(player.held_reusable_item):
		player.held_reusable_item.return_home()
		player.held_reusable_item = null
	if is_instance_valid(player.pickup_controller.holding):
		player.pickup_controller.drop_object()
	return true
