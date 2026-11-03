extends Node

var failures: int = 0

@onready var root: Window = get_tree().root

func _ready() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func click(player: Node3D, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	player._unhandled_input(event)

func aim(player: Node3D, point: Vector3) -> void:
	player.camera.global_position = point + Vector3(0, 1.0, 2)
	player.camera.look_at(point)
	player.interaction_raycast.force_raycast_update()

func run() -> void:
	var kitchen := load("res://scenes/kitchen.tscn").instantiate() as Node3D
	root.add_child(kitchen)
	get_tree().current_scene = kitchen
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player := kitchen.get_node("Player") as Node3D
	player.set_physics_process(false)
	var interaction: Node = player.get_node("DecorationInteraction")
	interaction.set_physics_process(false)
	var station := kitchen.get_node("DecorationStation") as Node3D
	var wall := station.get_node("DecorationWall") as DecorationWall
	var box := station.get_node("DecorationBox") as DecorationBox
	player.enter_wall_interaction(wall)
	for slot in wall.slots:
		player.camera.look_at(slot.global_position)
		player.interaction_raycast.force_raycast_update()
		check(player.interaction_raycast.get_collider() == wall, "Marker %s reachable from wall focus (hit %s, distance %.2f)" % [slot.name, player.interaction_raycast.get_collider(), player.camera.global_position.distance_to(slot.global_position)])
	player.exit_wall_interaction()
	check(wall.slots.size() == 13, "Only banner markers remain")
	check(wall.get_node_or_null("BalloonSlots") == null, "No fixed balloon markers")
	check(box.banner_bag.size() == 13, "Box contains only banner inventory")
	var supply := station.get_node("BalloonWeight") as BalloonSupply
	check(supply.variants.size() == 10, "Weight supplies ten balloons")
	check(player.get_node_or_null("DecorationInteraction/HUD") == null, "No reticle or instructional HUD")
	check(wall.get_node_or_null("Instructions") == null, "No wall instructions")
	check(not box.hover_label.visible and box.hover_label.text == "Decoration Box", "Only the box name appears on hover")
	var tape_sizes: Array[Vector3] = []
	for slot in wall.slots:
		if slot.kind == "banner":
			check(slot.get_child_count() == 1 and slot.tape.get_child_count() == 2, "Banner markers show crossed tape")
			tape_sizes.append(slot.tape.get_child(0).mesh.size)
		else:
			check(slot.tape == null and slot.get_child_count() == 0, "Balloon markers have no tape or ghosts")
	check(not tape_sizes[0].is_equal_approx(tape_sizes[1]), "Tape shapes vary between banner markers")
	var completed_count := [0]
	wall.completed.connect(func(): completed_count[0] += 1)
	await test_balloons(player, interaction, station, wall, supply, 0, 1)
	check(box.banner_bag.size() == 13 and wall.attached_balloons.size() == 1, "A balloon can be fully placed before taking any banners")
	var initial_balloon_count: int = wall.attached_balloons.size()
	var letters: Array[String] = []
	for index in 13:
		aim(player, box.global_position)
		check(player.interaction_raycast.get_collider() == box, "Box is reachable by the player's ray")
		interaction._physics_process(0.016)
		check(box._hovered, "Looking at box shows its name")
		click(player, true)
		click(player, false)
		var item: DecorationItem = interaction.held_item
		check(is_instance_valid(item), "Click box should hold a decoration")
		if item == null:
			break
		check(item.get_parent() == player.hand_socket, "Decoration shares player's hand socket")
		check(item.kind == "banner", "Box only supplies banners")
		if index < 13:
			letters.append(item.item_id)
		var target: DecorationSlot
		for slot in wall.slots:
			if slot.accepts(item):
				if target == null or slot.item_id != item.item_id:
					target = slot
		check(target != null, "Every draw can use an empty marker of its category")
		if index == 0:
			check(target.item_id != item.item_id, "A banner may use a different letter's marker")
		click(player, true)
		check(interaction.held_item == item, "Do not draw over a held piece")
		aim(player, wall.to_global(Vector3(0, -1.5, 0.1)))
		click(player, true)
		check(interaction.held_item == item and not item.placed, "Banner cannot attach away from its markers")
		aim(player, target.global_position)
		var before: Vector3 = item.global_position
		var floating_position: Vector3 = target.global_position + target.global_basis.z * DecorationItem.HOVER_DISTANCE
		interaction._physics_process(0.016)
		check(not box._hovered, "Looking away removes the box name")
		check(interaction.target_slot == target, "Empty category marker attracts the held decoration")
		check(item.global_position.distance_to(floating_position) < before.distance_to(floating_position), "Hover lerps toward the marker")
		check(not item.global_position.is_equal_approx(floating_position), "First hover frame does not teleport")
		click(player, false)
		check(interaction.held_item == item and not item.placed, "Release does not attach the hovering decoration")
		for frame in 60:
			interaction._physics_process(0.016)
		check(item.global_position.distance_to(floating_position) < 0.001, "Hover converges just in front of the marker")
		check(absf(item.global_basis.get_scale().x - DecorationItem.HOVER_SCALE) < 0.001, "Floating decoration is slightly larger")
		# Moving off the wall smoothly returns the same item to the hand.
		aim(player, box.global_position)
		for frame in 60:
			interaction._physics_process(0.016)
		check(item.position.distance_to(DecorationItem.HELD_POSITION) < 0.001, "Leaving marker returns item to hand")
		check(absf(item.scale.x - DecorationItem.HELD_SCALE) < 0.001, "Return restores held size")
		aim(player, target.global_position)
		interaction._physics_process(0.016)
		click(player, true)
		check(interaction.held_item == null, "New click confirms placement")
		check(target.occupant == item and item.get_parent() == target, "Item attaches to Marker3D")
		if target.kind == "banner":
			check(not target.tape.visible, "Placed banner covers its tape marker")
		check(item.transform.is_equal_approx(Transform3D.IDENTITY), "Snap uses marker rotation and scale")
		check(not wall.try_place(item, target.global_position), "Placed item cannot fill another marker")
		if index == 0:
			var count_before: int = wall.placed_count
			interaction.held_wall = null
			click(player, true)
			check(interaction.held_item == item and not item.placed, "Empty-handed click takes the placed banner")
			check(item.get_parent() == player.hand_socket, "Removed banner returns to the player's hand")
			check(target.occupant == null and target.tape.visible, "Removal frees the marker and restores its original tape")
			check(wall.placed_count == count_before - 1, "Removing banner updates placement count")
			check(box.banner_bag.size() == 12 and box.drawn_banners == 1, "Removing banner does not change box inventory")
			click(player, false)
			check(interaction.held_item == item, "Release after pickup does not reattach banner")
			var destination: DecorationSlot
			for slot in wall.slots:
				if slot != target and slot.accepts(item):
					destination = slot
					break
			aim(player, destination.global_position)
			interaction._physics_process(0.016)
			click(player, true)
			check(destination.occupant == item and target.occupant == null, "Removed banner can move to a different marker")
			check(wall.placed_count == count_before, "Moving banner does not duplicate its placement")
	letters.sort()
	var expected: Array[String] = []
	for letter in "HAPPYBIRTHDAY":
		expected.append(letter)
	expected.sort()
	check(letters == expected, "Random draws contain every letter exactly once, including duplicates")
	check(box.draw_item() == null, "Empty box cannot generate extra decorations")
	check(wall.placed_count == 13 + initial_balloon_count and completed_count[0] == 0, "Banners alone do not finish balloon stage")
	var first: DecorationSlot = wall.slots[0]
	var original: DecorationItem = first.occupant
	aim(player, first.global_position)
	player.held_reusable_item = kitchen.get_node("milkCarton")
	click(player, true)
	check(first.occupant == original and interaction.held_item == null, "Holding a kitchen item prevents banner pickup")
	player.held_reusable_item = null
	click(player, true)
	check(interaction.held_item == original and wall.placed_count == 12 + initial_balloon_count, "Completed arrangement remains editable")
	var second: DecorationSlot = wall.slots[1]
	var second_item: DecorationItem = second.occupant
	aim(player, second.global_position)
	click(player, true)
	check(interaction.held_item == original and second.occupant == second_item, "Holding a banner prevents taking or replacing another")
	aim(player, first.global_position)
	click(player, true)
	check(wall.placed_count == 13 + initial_balloon_count and completed_count[0] == 0, "Reattachment restores banner count")
	check(box.draw_item() == null, "Rearranging banners cannot create more inventory")
	await test_balloons(player, interaction, station, wall, supply, 1, 10)
	check(wall.placed_count == 23 and completed_count[0] == 1, "All thirteen banners and ten balloons finish the arrangement once")
	var rotated := load("res://prefabs/decoration_station.tscn").instantiate() as Node3D
	root.add_child(rotated)
	rotated.position = Vector3(-20, 3, 12)
	rotated.rotation.y = 1.2
	var rotated_box := rotated.get_node("DecorationBox") as DecorationBox
	var rotated_wall := rotated.get_node("DecorationWall") as DecorationWall
	var extra := rotated_box.draw_item()
	for slot in rotated_wall.slots:
		if slot.accepts(extra):
			check(rotated_wall.try_place(extra, slot.global_position), "Rotated station supports snapping")
			break
	print("Decoration flow: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	kitchen.free()
	rotated.free()
	get_tree().quit(1 if failures else 0)


func test_balloons(player: Node3D, interaction: Node, station: Node3D, wall: DecorationWall, supply: BalloonSupply, start_index: int, end_index: int) -> void:
	var pump := station.get_node("BalloonPump") as BalloonPump
	for index in range(start_index, end_index):
		aim(player, supply.global_position + Vector3.UP * 0.3)
		check(player.interaction_raycast.get_collider() == supply, "Weight is reachable by the player's ray")
		click(player, true)
		click(player, false)
		var balloon: PartyBalloon = interaction.held_item as PartyBalloon
		check(balloon != null, "Weight gives a deflated balloon")
		if balloon == null:
			return
		var actual_art_colors := {1: "Pink", 2: "Pink", 3: "Green", 4: "Green", 5: "Pink"}
		var color: String = actual_art_colors[balloon.variant]
		check(balloon.state == PartyBalloon.State.DEFLATED, "Draw starts deflated")
		check(balloon.sprite.texture.resource_path.ends_with("balloon_deflated%s.png" % color), "Deflated color matches variant family")
		var left: int = supply.variants.size()
		click(player, true)
		check(interaction.held_item == balloon and supply.variants.size() == left, "Held balloon blocks extra draws")
		var arbitrary_point := wall.to_global(Vector3(-2.4 + index * 0.48, 0.45 + (index % 2) * 0.4, 0.1))
		aim(player, arbitrary_point)
		click(player, true)
		check(interaction.held_item == balloon and wall.attached_balloons.size() == index, "Deflated balloon cannot attach to wall")
		aim(player, pump.nozzle.global_position)
		check(player.interaction_raycast.get_collider() == pump, "Pump nozzle is reachable by player's ray")
		var before: Vector3 = balloon.global_position
		var floating := pump.nozzle.global_position + pump.nozzle.global_basis.z * DecorationItem.HOVER_DISTANCE
		interaction._physics_process(0.016)
		check(balloon.global_position.distance_to(floating) < before.distance_to(floating), "Deflated balloon lerps toward nozzle")
		check(not balloon.global_position.is_equal_approx(floating), "Nozzle hover does not teleport")
		for frame in 60:
			interaction._physics_process(0.016)
		check(balloon.global_position.distance_to(floating) < 0.001, "Nozzle hover settles at nozzle")
		check(balloon.global_basis.y.normalized().dot(pump.nozzle.global_basis.y.normalized()) < -0.999, "Deflated balloon turns upside down by 180 degrees at nozzle")
		check(balloon.sprite.billboard == BaseMaterial3D.BILLBOARD_DISABLED, "Deflated pose retains the nozzle rotation")
		click(player, false)
		check(pump.occupant == null and balloon.state == PartyBalloon.State.DEFLATED, "Release does not inflate")
		click(player, true)
		check(interaction.held_item == null and pump.occupant == balloon, "Inflation leaves balloon on pump")
		check(balloon.state == PartyBalloon.State.INFLATING, "Pump starts inflation animation")
		check(not wall.try_place_balloon(balloon, arbitrary_point), "Inflating balloon cannot attach")
		click(player, true)
		check(interaction.held_item == null and pump.occupant == balloon, "Cannot take balloon before inflation finishes")
		aim(player, supply.global_position + Vector3.UP * 0.3)
		click(player, true)
		check(interaction.held_item == null and supply.variants.size() == left, "Occupied pump blocks a second draw so hands stay free for retrieval")
		aim(player, pump.nozzle.global_position)
		await get_tree().create_timer(0.55).timeout
		check(balloon.state == PartyBalloon.State.INFLATED, "Inflation finishes")
		check(balloon.sprite.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "Inflated balloon always faces the active camera")
		check(balloon.sprite.no_depth_test and balloon.sprite.render_priority > 0, "Inflated balloon draws above banners and cords")
		check(balloon.sprite.texture == balloon.hand_texture(), "Inflated pump image is the hand variant")
		check(balloon.sprite.scale.is_equal_approx(Vector3.ONE), "Inflation reaches full size")
		click(player, true)
		check(interaction.held_item == balloon and pump.occupant == null, "Click takes inflated balloon back to hand")
		check(balloon.get_parent() == player.hand_socket and balloon.sprite.texture == balloon.hand_texture(), "Hand keeps inflated no-string image")
		click(player, true)
		check(interaction.held_item == balloon and pump.occupant == null, "Inflated balloon cannot be pumped twice")
		aim(player, arbitrary_point)
		interaction._physics_process(0.016)
		check(interaction.target_slot == null, "Balloon wall preview uses no marker")
		for frame in 60:
			interaction._physics_process(0.016)
		var hit: Vector3 = player.interaction_raycast.get_collision_point()
		check(balloon.global_position.distance_to(wall.balloon_pose_at(hit, true).origin) < 0.001, "Balloon follows arbitrary wall point")
		click(player, false)
		check(interaction.held_item == balloon, "Wall preview needs a fresh click")
		click(player, true)
		check(interaction.held_item == null and balloon.state == PartyBalloon.State.ATTACHED, "Click attaches inflated balloon")
		check(balloon.sprite.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "Wall attachment keeps balloon facing player")
		check(balloon.sprite.no_depth_test and balloon.sprite.render_priority > wall.get_node("HappyString").render_priority, "Attached balloon and its string remain above banner cords")
		check(balloon.sprite.texture.resource_path.ends_with("balloon_%d.png" % balloon.variant), "Attached image includes ribbon and string")
		check(balloon.global_position.distance_to(wall.balloon_pose_at(hit).origin) < 0.001, "Attachment keeps exact chosen wall position")
		check(not wall.try_place_balloon(balloon, hit), "Attached balloon cannot be counted twice")
	if end_index == 10:
		var counts := [0, 0, 0, 0, 0]
		var pink: int = 0
		var green: int = 0
		for placed_balloon in wall.attached_balloons:
			counts[placed_balloon.variant - 1] += 1
			if placed_balloon.variant in [1, 2, 5]:
				pink += 1
			else:
				green += 1
		check(counts == [2, 2, 2, 2, 2] and pink == 6 and green == 4, "Variants 1–5 each occur twice, with six pink and four green")
		check(supply.draw_balloon() == null and supply.drawn_count == 10, "Weight cannot supply an eleventh balloon")
