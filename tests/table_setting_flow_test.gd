extends Node

# Integration test for the dining-table setting task: seven cabinet trips, five of each piece.

var failures: int = 0

@onready var root: Window = get_tree().root


func _ready() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func click(player: Node3D) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		player._unhandled_input(event)


# Aim from a standing eye height a couple of metres away, like a player would.
func aim(player: Node3D, point: Vector3, from_offset: Vector3) -> void:
	player.camera.global_position = point + from_offset
	player.camera.look_at(point)
	player.interaction_raycast.force_raycast_update()


func settle(interaction: Node, frames: int = 40) -> void:
	for _i in frames:
		interaction._physics_process(1.0 / 60.0)


func run() -> void:
	var kitchen := load("res://scenes/kitchen.tscn").instantiate() as Node3D
	root.add_child(kitchen)
	get_tree().current_scene = kitchen
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player := kitchen.get_node("Player") as Node3D
	player.set_physics_process(false)
	var interaction: Node = player.get_node("TableSettingInteraction")
	interaction.set_physics_process(false)
	var setting := kitchen.get_node("DiningTableSetting")
	var table := setting.get_node("DiningTable") as DiningTable
	var cabinet := setting.get_node("ChinaCabinet") as ChinaCabinet

	check(table.slots.size() == 5, "Table has five place-setting markers (got %d)" % table.slots.size())
	for slot in table.slots:
		check(slot.get_child_count() == 0, "Marker %s is invisible (no visuals)" % slot.name)

	var cabinet_view := Vector3(0, 0.2, 2.2)
	# Plates are locked until all chargers are set.
	check(cabinet.next_kind() == "charger" and cabinet.can_take(), "Cabinet offers chargers first")
	check(cabinet.get_node_or_null("Display") == null, "Nothing is shown outside the cabinet before taking it")

	var completed := [0]
	table.completed.connect(func(): completed[0] += 1)

	for kind in TableSettingItem.KIND_ORDER:
		aim(player, cabinet.global_position, cabinet_view)
		check(player.interaction_raycast.get_collider() == cabinet, "Cabinet is reachable by the player's ray")
		interaction._physics_process(1.0 / 60.0)
		check(cabinet._hovered, "Looking at the cabinet shows its name")
		check(player._get_interaction_reticle_target() == cabinet, "Reticle opens its hand over the cabinet")
		click(player)
		var stack: TableSettingStack = interaction.held_stack
		check(is_instance_valid(stack), "One click on the cabinet takes a stack of %ss" % kind)
		if not is_instance_valid(stack):
			break
		check(stack.kind == kind and stack.items.size() == 5, "Stack holds five %ss (got %s x%d)" % [kind, stack.kind, stack.items.size()])
		check(stack.get_parent() == player.hand_socket, "Stack is held in the shared hand socket")
		# Clicking the cabinet again while holding does nothing.
		aim(player, cabinet.global_position, cabinet_view)
		click(player)
		check(interaction.held_stack == stack and stack.items.size() == 5, "Holding a stack blocks another cabinet draw")
		var kind_index := TableSettingItem.KIND_ORDER.find(kind)
		if kind_index < TableSettingItem.KIND_ORDER.size() - 1:
			check(not cabinet.can_take(), "Next layer stays locked until every %s is placed" % kind)

		# Aiming at the table away from any marker: nothing floats, click does nothing.
		aim(player, table.global_position + Vector3(0.05, 0, 0.12), Vector3(0, 0.4, 2.6))
		interaction._physics_process(1.0 / 60.0)
		check(interaction.target_slot == null, "Table centre is not near any marker")
		click(player)
		check(stack.items.size() == 5, "Clicking away from markers places nothing")

		var order := table.slots.duplicate()
		order.reverse()
		for slot in order:
			var item: TableSettingItem = stack.top()
			var spot: Vector3 = slot.global_transform * TableSettingItem.offset_for(kind)
			spot.y = slot.global_position.y
			aim(player, spot + Vector3(0.05, 0, 0.04), Vector3(0, 0.4, 2.6) if slot.global_position.z > table.global_position.z else Vector3(0, 0.4, -2.6))
			check(player.interaction_raycast.get_collider() == table, "%s on table is reachable" % slot.name)
			settle(interaction)
			check(interaction.target_slot == slot, "Ray near %s targets it (got %s)" % [slot.name, interaction.target_slot])
			check(player._get_interaction_reticle_target() == table, "Reticle opens over a free marker")
			var hover_gap: float = item.global_position.distance_to(slot.global_transform * item.layer_transform().origin + Vector3.UP * TableSettingStack.HOVER_HEIGHT)
			check(hover_gap < 0.03, "%s floats over %s (gap %.3f)" % [kind, slot.name, hover_gap])
			check(item.get_parent() == stack, "Floating item stays in the stack until clicked")
			click(player)
			var expected_parent: Node = slot.layers.get("placecardStand") if kind == "placecard" else slot
			check(item.get_parent() == expected_parent and slot.layers.get(kind) == item, "Click sets the %s on %s" % [kind, slot.name])
			# The same marker can't take a second item of this kind.
			settle(interaction, 2)
			check(interaction.target_slot != slot, "Filled %s no longer targeted for %s" % [slot.name, kind])
		await get_tree().create_timer(0.2).timeout
		check(not is_instance_valid(interaction.held_stack), "Hands are empty after setting all five %ss" % kind)
		check(table.is_kind_complete(kind), "All five %ss are on the table" % kind)
		for slot in table.slots:
			var item: TableSettingItem = slot.layers.get(kind)
			var rest_gap: float = item.global_position.distance_to(slot.global_transform * item.layer_transform().origin)
			check(rest_gap < 0.002, "%s rests in place on %s (gap %.4f)" % [kind, slot.name, rest_gap])

	var names: Array[String] = []
	for slot in table.slots:
		check(slot.layers.size() == TableSettingItem.KIND_ORDER.size(), "%s has all %d pieces" % [slot.name, TableSettingItem.KIND_ORDER.size()])
		var charger: TableSettingItem = slot.layers.get("charger")
		var plate: TableSettingItem = slot.layers.get("plate")
		check(plate.global_position.y > charger.global_position.y, "Plate sits above charger on %s" % slot.name)
		check(plate.sprite.render_priority > charger.sprite.render_priority, "Plate draws over charger")
		var napkin: TableSettingItem = slot.layers.get("napkin")
		var fork: TableSettingItem = slot.layers.get("fork")
		check(fork.global_position.y > napkin.global_position.y and fork.sprite.render_priority > napkin.sprite.render_priority, "Fork lies on the napkin at %s" % slot.name)
		# Diner's left/right in the slot's own frame.
		var local := func(kind: String) -> Vector3: return slot.to_local(slot.layers.get(kind).global_position)
		check(local.call("napkin").x < 0 and local.call("knife").x > 0 and local.call("spoon").x > local.call("knife").x, "Napkin left, knife then spoon right at %s" % slot.name)
		check(local.call("glass").z < 0 and local.call("glass").x > 0, "Glass sits above-right at %s" % slot.name)
		check(slot.layers.get("glass").sprite.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y, "Glass stands upright facing the player")
		var stand: TableSettingItem = slot.layers.get("placecardStand")
		var card: TableSettingItem = slot.layers.get("placecard")
		check(stand.sprite.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y, "Card stand always faces the player")
		check(card.get_parent() == stand, "Card and stand become one item at %s" % slot.name)
		check(card.sprite.billboard == BaseMaterial3D.BILLBOARD_DISABLED and card.back_sprite != null, "Card is two-sided and does not turn")
		check(local.call("placecard").z < 0 and absf(local.call("placecard").x) < 0.01, "Card sits in front of the plate at %s" % slot.name)
		check(local.call("placecard").y > local.call("placecardStand").y, "Card rests on top of its stand")
		# Name side faces out toward the diner's chair (+Z) and leans back a little.
		var front_normal: Vector3 = slot.global_basis.inverse() * card.sprite.global_basis.z.normalized()
		check(front_normal.z > 0.9 and front_normal.y > 0.1, "Name faces outward, tilted up, at %s (%s)" % [slot.name, front_normal])
		var back_normal: Vector3 = slot.global_basis.inverse() * card.back_sprite.global_basis.z.normalized()
		check(back_normal.z < -0.9, "Blank back faces the table centre at %s" % slot.name)
		names.append(card.variant)
	names.sort()
	check(names == ["Amber", "Clay", "Diane", "Lindsey", "Mary"], "One card for each guest (got %s)" % [names])
	check(completed[0] == 1, "Table completion fires once")

	# Once every card is out, clicking one shows that guest's name card on screen.
	var view: NameCardView = player.name_card_view
	check(not view.visible, "Name card view starts hidden")
	for slot in table.slots:
		var card: TableSettingItem = slot.layers.get("placecard")
		var facing: Vector3 = slot.global_basis.z.normalized()
		aim(player, card.global_position, facing * 2.2 + Vector3.UP * 0.6)
		check(TableSettingItem.from_collider(player.interaction_raycast.get_collider()) == card, "Ray reaches %s's card" % card.variant)
		check(player._get_interaction_reticle_target() == player.interaction_raycast.get_collider(), "Reticle opens over a readable card")
		click(player)
		check(view.visible and view.guest_name == card.variant, "Clicking %s's card opens it (showing %s)" % [card.variant, view.guest_name])
		check(view.card.texture.resource_path.ends_with("placecard_UI.png"), "Close-up uses the large card art")
		var texts: Array[String] = []
		for node in view.find_children("*", "Label", true, false):
			if node.visible and not node.text.is_empty():
				texts.append(node.text)
		for node in view.find_children("*", "RichTextLabel", true, false):
			if node.visible and not node.text.is_empty():
				texts.append(node.text)
		check(texts == [card.variant], "Only the name is written on screen (got %s)" % [texts])
		var card_rect: Rect2 = Rect2(view.card.position, view.card.size)
		var screen_centre: Vector2 = view.get_viewport().get_visible_rect().size * 0.5
		check(card_rect.get_center().distance_to(screen_centre) < 1.0, "Card is centred on screen")
		check(player.is_card_view_open(), "Play pauses while the card is open")
		# Clicks while open don't do anything else, and only Esc closes it.
		click(player)
		check(view.visible, "Clicking again keeps the card open")
		var escape := InputEventAction.new()
		escape.action = "escape"
		escape.pressed = true
		view._unhandled_input(escape)
		check(not view.visible, "Esc closes the name card")
	check(cabinet.next_kind() == "" and not cabinet.can_take(), "Cabinet is empty when all layers are taken")

	print("Table setting flow: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)
