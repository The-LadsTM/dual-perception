extends Node3D
@onready var audio_player = $AudioStreamPlayer3D
var sounds = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func check_voicemail():
	audio_player.play()
	if Dialogic.current_timeline != null:
		return
	Dialogic.start("phone_1")
