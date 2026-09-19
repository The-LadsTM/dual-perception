class_name BaseScene extends Node

@onready var player: Player = %Player
#@onready var entrance_markers: Node2D = $EntranceMarkers
# Called when the node enters the scene tree for the first time.
func _ready():
	#print_debug(player)
	if SceneManager.player:
		print_debug(SceneManager.player)
		if player:
			player.queue_free()
		player = SceneManager.player
		add_child(player)
	else: 
		SceneManager.player = player
	#position_player()
	#var full_path = str("res://locations/", name, ".tscn")
	#scene_manager.player_info["location"] = full_path
	print_debug(self)
