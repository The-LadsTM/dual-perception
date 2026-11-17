class_name TableSettingItem
extends Node3D

const SPRITE_DIR := "res://assets/house/Dining Room/Sprites/"

# Layers are taken from the china cabinet and set on the table in this order;
# each one needs every earlier layer already on that place setting.
const KIND_ORDER: Array[String] = [
	"charger", "plate", "napkin", "fork", "knife", "spoon", "glass", "placecardStand", "placecard",
]

# Per-kind layout inside a TableSettingSlot, in the slot's local space as seen by
# the diner (who sits on the slot's +Z side, facing -Z):
#   offset.x  - is the diner's left, + is their right
#   offset.y  - height above the tabletop (higher layers draw on top)
#   offset.z  - is away from the diner (toward the table centre)
# Classic setting: napkin + fork on the left, knife (blade toward the plate) then
# spoon on the right, water glass above the knife, place card above the plate.
#
# Optional keys:
#   upright    - side-view art: stands on the table and always turns to face the player
#   variants   - each item in a cabinet stack gets a different one (texture "%s" is filled in)
#   back       - texture for the back face of a two-sided card
#   tilt       - degrees the card leans back (top away from the diner)
#   mount_on   - once placed, becomes part of that kind's item in the same slot
const KINDS: Dictionary = {
	"charger": {"texture": "charger.png", "offset": Vector3(0, 0.004, 0), "priority": 1},
	"plate": {"texture": "pinkPlate.png", "offset": Vector3(0, 0.012, 0), "priority": 2},
	"napkin": {"texture": "napkin_Folded.png", "offset": Vector3(-0.45, 0.004, 0.0), "priority": 1},
	"fork": {"texture": "fork.png", "offset": Vector3(-0.45, 0.012, 0.0), "priority": 2},
	"knife": {"texture": "knife.png", "offset": Vector3(0.39, 0.004, 0.0), "priority": 1},
	"spoon": {"texture": "spoon.png", "offset": Vector3(0.51, 0.004, 0.0), "priority": 1},
	"glass": {"texture": "glass.png", "offset": Vector3(0.42, 0.0, -0.42), "priority": 3, "upright": true},
	"placecardStand": {"texture": "placecardStand.png", "offset": Vector3(0, 0.0, -0.42), "priority": 3, "upright": true},
	# Name side faces out toward the diner's chair, blank back faces the table centre.
	"placecard": {
		"texture": "placecard_%s.png",
		"back": "placecard.png",
		"variants": ["Mary", "Lindsey", "Diane", "Clay", "Amber"],
		"offset": Vector3(0, 0.185, -0.415),
		"tilt": 12.0,
		"priority": 4,
		"mount_on": "placecardStand",
	},
}
# 378 px charger -> ~0.6 m; every sprite shares this so the art keeps its relative sizes.
const PIXEL_SIZE: float = 0.0016

var kind: String = ""
var variant: String = ""
var placed: bool = false
var sprite: Sprite3D # front face
var back_sprite: Sprite3D


static func texture_for(item_kind: String, item_variant: String = "") -> Texture2D:
	var file: String = KINDS[item_kind]["texture"]
	if file.contains("%s"):
		file = file % item_variant
	return load(SPRITE_DIR + file) as Texture2D


static func variants_for(item_kind: String) -> Array:
	return KINDS[item_kind].get("variants", [])


static func is_upright(item_kind: String) -> bool:
	return KINDS[item_kind].get("upright", false)


static func is_card(item_kind: String) -> bool:
	return KINDS[item_kind].has("back")


# Where this kind rests inside a slot (slot-local).
static func offset_for(item_kind: String) -> Vector3:
	var offset: Vector3 = KINDS[item_kind]["offset"]
	if is_upright(item_kind):
		# Stand the sprite on the table: lift by half its height.
		offset.y += texture_for(item_kind).get_height() * PIXEL_SIZE * 0.5 + 0.002
	return offset


# Resting orientation inside a slot.
static func basis_for(item_kind: String) -> Basis:
	return Basis(Vector3.RIGHT, -deg_to_rad(KINDS[item_kind].get("tilt", 0.0)))


# Orientation inside the player's hand stack, where every item's face points up
# (+Y) like the flat tableware.
static func hand_basis(item_kind: String) -> Basis:
	return Basis(Vector3.RIGHT, -PI * 0.5) if is_card(item_kind) else Basis.IDENTITY


func setup(item_kind: String, item_variant: String = "") -> void:
	kind = item_kind
	variant = item_variant
	name = item_kind.capitalize() + ("_" + variant if not variant.is_empty() else "")
	sprite = _make_sprite(texture_for(kind, variant))
	if is_card(kind):
		# Two sprites back to back make one two-sided card; each only shows from its own side.
		sprite.double_sided = false
		sprite.position.z = 0.0008
		back_sprite = _make_sprite(load(SPRITE_DIR + KINDS[kind]["back"]))
		back_sprite.double_sided = false
		back_sprite.rotation.y = PI
		back_sprite.position.z = -0.0008
	elif is_upright(kind):
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	else:
		# Lie flat on the table, art facing up, its top pointing away from the diner.
		sprite.axis = Vector3.AXIS_Y


func _make_sprite(texture: Texture2D) -> Sprite3D:
	var made := Sprite3D.new()
	made.texture = texture
	made.pixel_size = PIXEL_SIZE
	made.shaded = false
	made.double_sided = true
	made.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	made.render_priority = KINDS[kind]["priority"]
	add_child(made)
	return made


# Thin collider matching the card so the player's ray can click it once it is
# on the table. Its parent (this item) identifies which card was clicked.
func add_click_body() -> void:
	if get_node_or_null("ClickBody") != null:
		return
	var body := StaticBody3D.new()
	body.name = "ClickBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var texture := sprite.texture
	box.size = Vector3(texture.get_width() * PIXEL_SIZE, texture.get_height() * PIXEL_SIZE, 0.03)
	shape.shape = box
	body.add_child(shape)
	add_child(body)


static func from_collider(collider: Object) -> TableSettingItem:
	var body := collider as Node
	if body == null or body.name != "ClickBody":
		return null
	return body.get_parent() as TableSettingItem


# Resting pose inside a TableSettingSlot (slot-local).
func layer_transform() -> Transform3D:
	return Transform3D(basis_for(kind), offset_for(kind))
