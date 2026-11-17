
extends CanvasLayer

@onready var pause_button: Button = $PauseButton
@onready var pause_menu: Control = $Pause


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS

	pause_menu.hide()
	pause_button.show()

	pause_button.pressed.connect(open_pause_menu)


func open_pause_menu() -> void:
	pause_menu.show()
	pause_button.hide()
	get_tree().paused = true


func resume_game() -> void:
	get_tree().paused = false
	pause_menu.hide()
	pause_button.show()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				if pause_menu.visible:
					resume_game()
				else:
					open_pause_menu()
				get_viewport().set_input_as_handled()
