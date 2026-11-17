extends Node

var held_item: DecorationItem
var held_wall: DecorationWall
var target_slot: DecorationSlot
var hovered_box: DecorationBox
var hovered_supply: BalloonSupply

@onready var player: Player = get_parent()


func _physics_process(delta: float) -> void:
	if player.recipe_card_view.visible:
		_set_hovered_box(null)
		_set_hovered_supply(null)
		return
	var ray := player.interaction_raycast
	ray.force_raycast_update()
	_set_hovered_box(ray.get_collider() as DecorationBox)
	_set_hovered_supply(ray.get_collider() as BalloonSupply)
	target_slot = null
	if is_instance_valid(held_item) and is_instance_valid(held_wall):
		if held_item is PartyBalloon:
			var balloon := held_item as PartyBalloon
			var pump := ray.get_collider() as BalloonPump
			if pump != null and pump.can_inflate(balloon):
				balloon.update_pump_hover(pump.nozzle, delta)
			elif balloon.state == PartyBalloon.State.INFLATED and ray.get_collider() == held_wall:
				balloon.update_hover_transform(held_wall.balloon_pose_at(ray.get_collision_point(), true), delta)
			else:
				balloon.update_hover_pose(null, delta)
			return
		if ray.get_collider() == held_wall:
			target_slot = held_wall.find_slot(held_item, ray.get_collision_point())
		held_item.update_hover_pose(target_slot, delta)


func _set_hovered_supply(supply: BalloonSupply) -> void:
	if hovered_supply != supply and is_instance_valid(hovered_supply):
		hovered_supply.set_hovered(false)
	hovered_supply = supply
	# Hands or stock can change while the ray remains on the same bag.
	if is_instance_valid(hovered_supply):
		hovered_supply.set_hovered(_hands_empty())


func _set_hovered_box(box: DecorationBox) -> void:
	if hovered_box == box:
		return
	if is_instance_valid(hovered_box):
		hovered_box.set_hovered(false)
	hovered_box = box
	if is_instance_valid(hovered_box):
		hovered_box.set_hovered(true)


func is_reticle_target(target: Node3D) -> bool:
	if target == hovered_box:
		return not is_instance_valid(held_item) and not hovered_box.banner_bag.is_empty()
	if target == hovered_supply:
		return (
			_hands_empty()
			and not hovered_supply.variants.is_empty()
			and not is_instance_valid(hovered_supply.pump.occupant)
		)
	if target is BalloonPump:
		if held_item is PartyBalloon:
			return target.can_inflate(held_item)
		return (
			_hands_empty()
			and is_instance_valid(target.occupant)
			and target.occupant.state == PartyBalloon.State.INFLATED
		)
	if target == held_wall:
		return is_instance_valid(target_slot) or (held_item is PartyBalloon and held_item.state == PartyBalloon.State.INFLATED)
	return false


func handle_input(event: InputEvent) -> bool:
	if not event.is_action("interact"):
		return false
	if event.is_action_released("interact"):
		# Hovering and releasing only preview; a fresh click confirms placement.
		return is_instance_valid(held_item)
	if not event.is_action_pressed("interact"):
		return false
	if is_instance_valid(held_item):
		if held_item is PartyBalloon:
			player.interaction_raycast.force_raycast_update()
			var pump := player.interaction_raycast.get_collider() as BalloonPump
			if pump != null and pump.inflate_balloon(held_item as PartyBalloon):
				held_item = null
			else:
				try_place()
		else:
			try_place()
		return true
	player.interaction_raycast.force_raycast_update()
	var supply := player.interaction_raycast.get_collider() as BalloonSupply
	if supply != null:
		if _hands_empty():
			held_item = supply.draw_balloon()
			if held_item != null:
				held_wall = supply.box.wall
				held_item.hold(player.hand_socket)
		return true
	var pump := player.interaction_raycast.get_collider() as BalloonPump
	if pump != null:
		if _hands_empty():
			held_item = pump.take_balloon()
			if held_item != null:
				held_wall = pump.wall
				held_item.hold(player.hand_socket)
		return true
	var wall := player.interaction_raycast.get_collider() as DecorationWall
	if wall != null and _hands_empty():
		var item := wall.take_banner_at(player.interaction_raycast.get_collision_point())
		if item != null:
			held_wall = wall
			held_item = item
			held_item.hold(player.hand_socket)
			return true
	var box := player.interaction_raycast.get_collider() as DecorationBox
	if box == null:
		return false
	# Share the player's hands with the existing kitchen interactions.
	if is_instance_valid(player.held_reusable_item):
		player.held_reusable_item.return_home()
		player.held_reusable_item = null
	if is_instance_valid(player.held_consumable):
		player.held_consumable.queue_free()
		player.held_consumable = null
	if is_instance_valid(player.pickup_controller.holding):
		player.pickup_controller.drop_object()
	held_wall = box.wall
	held_item = box.draw_item()
	if held_item != null:
		held_item.hold(player.hand_socket)
	return true


func _hands_empty() -> bool:
	return not is_instance_valid(held_item) and not is_instance_valid(player.held_reusable_item) and not is_instance_valid(player.held_consumable) and not is_instance_valid(player.held_tool) and not is_instance_valid(player.pickup_controller.holding)


func try_place() -> bool:
	var ray := player.interaction_raycast
	ray.force_raycast_update()
	if not is_instance_valid(held_wall) or ray.get_collider() != held_wall:
		return false
	var placed: bool
	if held_item is PartyBalloon:
		placed = held_wall.try_place_balloon(held_item as PartyBalloon, ray.get_collision_point())
	else:
		placed = held_wall.try_place(held_item, ray.get_collision_point())
	if not placed:
		return false
	held_item = null
	target_slot = null
	return true
