class_name BalloonPump
extends StaticBody3D

var occupant: PartyBalloon
@onready var nozzle: Marker3D = $Nozzle
@onready var wall: DecorationWall = get_node("../DecorationWall") as DecorationWall


func can_inflate(balloon: PartyBalloon) -> bool:
	return not is_instance_valid(occupant) and balloon.state == PartyBalloon.State.DEFLATED


func inflate_balloon(balloon: PartyBalloon) -> bool:
	if not can_inflate(balloon):
		return false
	occupant = balloon
	balloon.reparent(nozzle)
	balloon.transform = Transform3D.IDENTITY
	balloon.inflate()
	return true


func take_balloon() -> PartyBalloon:
	if not is_instance_valid(occupant) or occupant.state != PartyBalloon.State.INFLATED:
		return null
	var balloon := occupant
	occupant = null
	return balloon
