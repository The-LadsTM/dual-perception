class_name InteractionReticle
extends Control

enum State { DEFAULT, HOVER, GRAB }

const CIRCLE_BLEND := Vector2(1.0, 0.0)
const OPEN_HAND_BLEND := Vector2(0.0, 1.0)

@export var open_hand_icon: Texture2D
@export var closed_hand_icon: Texture2D
@export_range(4.0, 64.0, 1.0) var circle_diameter: float = 16.0
@export_range(0.5, 3.0, 0.5) var circle_thickness: float = 2.0
@export_range(0.0, 1.0, 0.01) var circle_opacity: float = 0.6
@export_range(4.0, 64.0, 1.0) var hand_size: float = 24.0
@export_range(0.0, 1.0, 0.01) var hand_opacity: float = 0.9
@export_range(0.01, 1.0, 0.01) var hover_duration: float = 0.12
@export_range(0.01, 1.0, 0.01) var grab_duration: float = 0.15
@export_range(0.1, 1.0, 0.01) var grab_min_scale: float = 0.85

var _state := State.DEFAULT
var _suppressed_target_id: int = 0
var _transition: Tween
var _blend := CIRCLE_BLEND:
	set(value):
		_blend = value
		queue_redraw()
var _grab_scale: float = 1.0:
	set(value):
		_grab_scale = value
		queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)
	get_viewport().size_changed.connect(queue_redraw)


func set_target(target: Node3D) -> void:
	var target_id := target.get_instance_id() if is_instance_valid(target) else 0
	if target_id != _suppressed_target_id:
		_suppressed_target_id = 0
	if _state == State.GRAB:
		return
	var next := State.HOVER if target_id != 0 and _suppressed_target_id == 0 else State.DEFAULT
	if _state == next:
		return
	_state = next
	_start_transition()
	var blend := OPEN_HAND_BLEND if _state == State.HOVER else CIRCLE_BLEND
	_transition.tween_property(self, "_blend", blend, hover_duration)


func play_grab(source: Node3D) -> void:
	_suppressed_target_id = source.get_instance_id() if is_instance_valid(source) else 0
	if _state == State.GRAB:
		return
	_state = State.GRAB
	_start_transition()
	_grab_scale = 1.0
	_transition.tween_property(self, "_grab_scale", grab_min_scale, grab_duration * 0.5)
	_transition.tween_property(self, "_grab_scale", 1.0, grab_duration * 0.5)
	_transition.tween_callback(_finish_grab)


func _start_transition() -> void:
	if _transition != null:
		_transition.kill()
	_transition = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _finish_grab() -> void:
	_state = State.DEFAULT
	_blend = CIRCLE_BLEND


func _draw() -> void:
	# Keep the glyph in screen pixels even with the project's canvas stretch.
	var pixel_scale := Vector2.ONE / get_viewport().get_stretch_transform().get_scale()
	draw_set_transform(size * 0.5, 0.0, pixel_scale)
	if _state == State.GRAB:
		_draw_hand(closed_hand_icon, hand_size * _grab_scale, hand_opacity)
		return
	if _blend.x > 0.0:
		var radius := (circle_diameter - circle_thickness) * 0.5
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, circle_opacity * _blend.x), circle_thickness, true)
	if _blend.y > 0.0:
		_draw_hand(open_hand_icon, hand_size, hand_opacity * _blend.y)


func _draw_hand(icon: Texture2D, side: float, opacity: float) -> void:
	var extent := Vector2.ONE * side
	draw_texture_rect(icon, Rect2(-extent * 0.5, extent), false, Color(1.0, 1.0, 1.0, opacity))
