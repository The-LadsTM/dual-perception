
extends Control

const MAIN_MENU_PATH = "res://main_menu.tscn"

var resume_button: Button
var quit_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Find Resume and Quit buttons.
	resume_button = find_child("Resume", true, false) as Button
	quit_button = find_child("QuitButton", true, false) as Button

	if resume_button == null:
		push_error("Resume button not found!")
	else:
		resume_button.process_mode = Node.PROCESS_MODE_ALWAYS
		resume_button.disabled = false

		if not resume_button.pressed.is_connected(_on_resume_pressed):
			resume_button.pressed.connect(_on_resume_pressed)

	if quit_button == null:
		push_error("QuitButton not found!")
	else:
		quit_button.process_mode = Node.PROCESS_MODE_ALWAYS
		quit_button.disabled = false

		if not quit_button.pressed.is_connected(_on_quit_pressed):
			quit_button.pressed.connect(_on_quit_pressed)


func _on_resume_pressed() -> void:
	print("RESUME CLICKED")

	var global_ui = get_node_or_null("/root/GlobalPauseUI")

	if global_ui != null and global_ui.has_method("resume_game"):
		global_ui.resume_game()
	else:
		get_tree().paused = false
		hide()


func _on_quit_pressed() -> void:
	print("QUIT CLICKED")

	get_tree().paused = false
	hide()

	var error = get_tree().change_scene_to_file(MAIN_MENU_PATH)

	if error != OK:
		push_error("Could not load Main Menu!")
