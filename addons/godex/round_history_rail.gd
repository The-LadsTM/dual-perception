@tool
extends Control

signal round_hovered(round_index: int, marker_y: float)
signal round_unhovered
signal round_activated(round_index: int)

var _rounds: Array[Dictionary] = []
var _hovered_round := -1
var _active_round := -1
var _search_matches: Dictionary = {}
var _active_search_round := -1


func _ready() -> void:
	custom_minimum_size = Vector2(28.0, 0.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_exited.connect(_on_mouse_exited)


func set_rounds(rounds: Array[Dictionary], active_round: int) -> void:
	_rounds = rounds.duplicate(true)
	_active_round = clampi(active_round, -1, _rounds.size() - 1)
	if _hovered_round >= _rounds.size():
		_hovered_round = -1
	queue_redraw()


func set_active_round(round_index: int) -> void:
	var next_active := clampi(round_index, -1, _rounds.size() - 1)
	if next_active == _active_round:
		return
	_active_round = next_active
	queue_redraw()


func set_search_matches(
	round_indices: PackedInt32Array,
	active_search_round: int
) -> void:
	_search_matches.clear()
	for round_index in round_indices:
		_search_matches[int(round_index)] = true
	_active_search_round = active_search_round
	queue_redraw()


func _marker_y(round_index: int) -> float:
	if round_index < 0 or round_index >= _rounds.size():
		return 0.0
	var top_margin := 8.0
	var bottom := maxf(size.y - 8.0, top_margin)
	var fallback_position := (
		0.0
		if _rounds.size() <= 1
		else float(round_index) / float(_rounds.size() - 1)
	)
	var normalized := clampf(
		float(_rounds[round_index].get("position", fallback_position)),
		0.0,
		1.0
	)
	return lerpf(top_margin, bottom, normalized)


func _round_at_y(local_y: float) -> int:
	var closest_index := -1
	var closest_distance := 8.0
	for round_index in range(_rounds.size()):
		var distance := absf(local_y - _marker_y(round_index))
		if distance <= closest_distance:
			closest_index = round_index
			closest_distance = distance
	return closest_index


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var next_hovered := _round_at_y(motion.position.y)
		if next_hovered == _hovered_round:
			return
		_hovered_round = next_hovered
		queue_redraw()
		if _hovered_round >= 0:
			round_hovered.emit(
				_hovered_round,
				_marker_y(_hovered_round)
			)
		else:
			round_unhovered.emit()
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if (
			button.button_index == MOUSE_BUTTON_LEFT
			and button.pressed
			and _hovered_round >= 0
		):
			round_activated.emit(_hovered_round)
			accept_event()


func _on_mouse_exited() -> void:
	if _hovered_round < 0:
		return
	_hovered_round = -1
	queue_redraw()
	round_unhovered.emit()


func _draw() -> void:
	var normal_color := Color(0.68, 0.70, 0.74, 0.48)
	var active_color := Color(0.35, 0.65, 1.0, 0.95)
	var search_color := Color(0.96, 0.68, 0.28, 0.96)
	var active_search_color := Color(1.0, 0.84, 0.42, 1.0)
	var hovered_color := Color(0.94, 0.96, 1.0, 1.0)
	for round_index in range(_rounds.size()):
		var marker_width := 8.0
		var marker_thickness := 1.0
		var marker_color := normal_color
		if round_index == _active_round:
			marker_width = 14.0
			marker_thickness = 2.0
			marker_color = active_color
		if _search_matches.has(round_index):
			marker_width = maxf(marker_width, 16.0)
			marker_thickness = 2.0
			marker_color = search_color
		if round_index == _active_search_round:
			marker_width = 20.0
			marker_thickness = 3.0
			marker_color = active_search_color
		if round_index == _hovered_round:
			marker_width = 20.0
			marker_thickness = 2.0
			marker_color = hovered_color
		var right_edge := size.x - 4.0
		var marker_y := _marker_y(round_index)
		draw_line(
			Vector2(right_edge - marker_width, marker_y),
			Vector2(right_edge, marker_y),
			marker_color,
			marker_thickness,
			true
		)
