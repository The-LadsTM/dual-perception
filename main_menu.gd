
extends Control

@onready var play_button: Button = $MenuLayout/PlayButton
@onready var exit_button: Button = $MenuLayout/ExitButton
@onready var controls_button: Button = $MenuLayout/GameControlsButton
@onready var controls_popup: Control = $ControlsPopup

func _ready() -> void:
	print("MAIN MENU READY")

	play_button.pressed.connect(_on_play_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	controls_button.pressed.connect(_on_controls_pressed)

	controls_popup.hide()


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/kitchen.tscn")


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_controls_pressed() -> void:
	print("GAME CONTROLS CLICKED")

	controls_popup.show()
	controls_popup.move_to_front()

	print("POPUP VISIBLE: ", controls_popup.visible)


func _input(event: InputEvent) -> void:
	if not controls_popup.visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			controls_popup.hide()
			get_viewport().set_input_as_handled()
