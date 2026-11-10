extends CanvasLayer

var player: Player
var photo_gallery = []
@onready var photo = $PhotoContainer/Photo
@onready var photo_cooldown = $Photo_cooldown
@onready var cooldown_bar = $CameraCooldownBar
var bowl_array = [];
var correct_array = []

var bowl_contents: Dictionary[String, int] = {}
var recipe_contents: Dictionary[String, int] = {
	"sugarJar": 1,
	"flourJar": 3,
	"milkCarton": 1,
	"saltShaker": 1,
	"eggCarton": 3,
	"butter": 1,
}

var pair_dict = { "sugarJar_flourJar": false, "butter_cheese": false, "salt_soda": false, "eggCarton": true }

signal change_texture;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	swap_items();
	print_debug("swapped")
	$PhotoContainer.visible = false;
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	cooldown_bar.value = $CameraCooldown.time_left
	if photo_gallery.size() > 0:
		photo.texture = ImageTexture.create_from_image(photo_gallery[photo_gallery.size()-1])

#func change_scene(from, to_scene_name: String):
	
	

func add_to_gallery(pic):
	photo_gallery.append(pic);
	$PhotoContainer.visible = true
	photo_cooldown.start()


func _on_photo_cooldown_timeout() -> void:
	$PhotoContainer.visible = false;


func _on_camera_cooldown_timeout() -> void:
	player.retake = true

func get_random_item(true_item: String):
	for pair in pair_dict:
		if pair.contains(true_item):
			var string = pair.replace(true_item, "");
			string = string.remove_chars("_");
			if pair_dict[pair]:
				return string;
			else:
				return true_item;

func swap_items():
	for pair in pair_dict:
		if randi() % 2:
			pair_dict[pair] = false
		else:
			pair_dict[pair] = true

func add_to_bowl(ingredient: String):
	bowl_array.append(ingredient)
	if bowl_contents.has(ingredient):
		bowl_contents[ingredient] += 1;
	else:
		bowl_contents.set(ingredient, 1)
	print_debug(bowl_contents)

func check_correct() -> bool:
	for i in recipe_contents:
		if !bowl_contents.has(i) or !(bowl_contents[i] == recipe_contents[i]):
			return false
	return true
	
