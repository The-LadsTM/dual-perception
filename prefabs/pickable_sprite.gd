class_name PickableSprite extends RigidBody3D

@export var true_item: String;
var random_item;
var asset_path = "res://assets/"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	random_item = SceneManager.get_random_item(true_item);
	print_debug(random_item)
	if random_item:
		$Sprite3D.texture = load(asset_path + "SPR_KitchenAssets_Merged_v03"+".png")
	else:
		$Sprite3D.texture = load(asset_path + "SPR_KitchenAssets_Merged_v03"+".png")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
