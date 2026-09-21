extends CanvasLayer

var player: Player
var photo_gallery = []
@onready var photo = $Photo
@onready var photo_cooldown = $Photo_cooldown
@onready var cooldown_bar = $CameraCooldownBar

signal change_texture;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#photo.visible = false;
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	cooldown_bar.value = $CameraCooldown.time_left
	if photo_gallery.size() > 0:
		photo.texture = ImageTexture.create_from_image(photo_gallery[photo_gallery.size()-1])

#func change_scene(from, to_scene_name: String):
	
	

func add_to_gallery(pic):
	photo_gallery.append(pic);
	photo.visible = true
	photo_cooldown.start()


func _on_photo_cooldown_timeout() -> void:
	photo.visible = false;


func _on_camera_cooldown_timeout() -> void:
	player.retake = true
