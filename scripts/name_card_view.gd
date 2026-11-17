class_name NameCardView
extends CanvasLayer

# Full-screen close-up of a guest's place card: the large card art with the
# guest's name written on it, centred on screen. Esc closes it. Deliberately
# shows no other text (no hints, no instructions).

signal closed

const CARD_TEXTURE: Texture2D = preload("res://assets/house/Dining Room/Sprites/placecard_UI.png")
# Handwritten script like the names on the small table cards. Uses the
# system's script face (macOS: Snell Roundhand / Apple Chancery, Windows:
# Segoe Script / Brush Script), falling back to the default font elsewhere.
const NAME_FONT_FAMILIES: PackedStringArray = [
	"Snell Roundhand", "Apple Chancery", "Segoe Script", "Brush Script MT", "Lucida Handwriting", "cursive",
]
# Same cream as the names on the small table cards.
const NAME_COLOR := Color(0.95, 0.91, 0.84)
const SCREEN_FRACTION: float = 0.62

var guest_name: String = ""
var _open_tween: Tween

var card: TextureRect
var name_label: Label


func _ready() -> void:
	layer = 100
	var overlay := Control.new()
	overlay.name = "Overlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0, 0, 0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(backdrop)

	card = TextureRect.new()
	card.name = "Card"
	card.texture = CARD_TEXTURE
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(card)

	name_label = Label.new()
	name_label.name = "Name"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	var font := SystemFont.new()
	font.font_names = NAME_FONT_FAMILIES
	name_label.add_theme_font_override("font", font)
	name_label.add_theme_color_override("font_color", NAME_COLOR)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_label)

	get_viewport().size_changed.connect(_layout)
	hide()


func open_card(guest: String) -> void:
	guest_name = guest
	name_label.text = guest
	show()
	_layout()
	if _open_tween != null:
		_open_tween.kill()
	card.scale = Vector2.ONE * 0.94
	card.modulate.a = 0.0
	_open_tween = create_tween().set_parallel(true)
	_open_tween.tween_property(card, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(card, "modulate:a", 1.0, 0.12)


func close_card() -> void:
	if not visible:
		return
	if _open_tween != null:
		_open_tween.kill()
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("escape"):
		close_card()
	# While the card is up, nothing else in the game reacts to input.
	get_viewport().set_input_as_handled()


# Keep the card centred and sized to the screen, preserving the art's aspect.
func _layout() -> void:
	if not is_instance_valid(card):
		return
	var screen := get_viewport().get_visible_rect().size
	var aspect := float(CARD_TEXTURE.get_width()) / float(CARD_TEXTURE.get_height())
	var width := minf(screen.x * SCREEN_FRACTION, screen.y * SCREEN_FRACTION * aspect)
	var size := Vector2(width, width / aspect)
	card.size = size
	card.position = (screen - size) * 0.5
	card.pivot_offset = size * 0.5
	name_label.add_theme_font_size_override("font_size", int(size.y * 0.3))
