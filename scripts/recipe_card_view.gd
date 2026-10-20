class_name RecipeCardView
extends CanvasLayer

signal closed

var _open_tween: Tween

@onready var _aspect: AspectRatioContainer = $Overlay/Margin/Column/Aspect
@onready var _card_button: Button = $Overlay/Margin/Column/Aspect/CardButton
@onready var _paper: TextureRect = $Overlay/Margin/Column/Aspect/CardButton/Paper
@onready var _content: MarginContainer = $Overlay/Margin/Column/Aspect/CardButton/Content
@onready var _title: Label = $Overlay/Margin/Column/Aspect/CardButton/Content/Scroll/Text/Title
@onready var _body: Label = $Overlay/Margin/Column/Aspect/CardButton/Content/Scroll/Text/Body
@onready var _scroll: ScrollContainer = $Overlay/Margin/Column/Aspect/CardButton/Content/Scroll


func _ready() -> void:
	hide()
	_card_button.pressed.connect(close_card)
	_card_button.resized.connect(_resize_card)


func open_card(title: String, body: String, texture: Texture2D) -> void:
	_title.text = title
	_title.visible = not title.is_empty()
	_body.text = body
	_body.visible = not body.is_empty()
	_paper.texture = texture
	_aspect.ratio = float(texture.get_width()) / float(texture.get_height())
	_scroll.scroll_vertical = 0
	show()
	_resize_card()
	_card_button.grab_focus()
	if _open_tween != null:
		_open_tween.kill()
	_card_button.scale = Vector2.ONE * 0.94
	_open_tween = create_tween()
	_open_tween.tween_property(_card_button, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func close_card() -> void:
	if not visible:
		return
	if _open_tween != null:
		_open_tween.kill()
	_card_button.release_focus()
	hide()
	closed.emit()
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("escape"):
		close_card()


func _resize_card() -> void:
	_card_button.pivot_offset = _card_button.size * 0.5
	var horizontal_margin: int = int(_card_button.size.x * 0.1)
	var vertical_margin: int = int(_card_button.size.y * 0.08)
	_content.add_theme_constant_override("margin_left", horizontal_margin)
	_content.add_theme_constant_override("margin_right", horizontal_margin)
	_content.add_theme_constant_override("margin_top", vertical_margin)
	_content.add_theme_constant_override("margin_bottom", vertical_margin)
	_title.add_theme_font_size_override("font_size", clampi(int(_card_button.size.y * 0.07), 24, 48))
	_body.add_theme_font_size_override("font_size", clampi(int(_card_button.size.y * 0.045), 16, 30))
