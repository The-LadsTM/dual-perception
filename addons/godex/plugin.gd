@tool
extends EditorPlugin

const DOCK_CONTENT_SCRIPT := preload("res://addons/godex/godex.gd")

var _dock: EditorDock
var _content: Control
var _toolbar_button: Button


func _enter_tree() -> void:
	_dock = EditorDock.new()
	_dock.title = "Godex"
	_dock.layout_key = "godex"
	_dock.default_slot = EditorDock.DOCK_SLOT_RIGHT_BR
	_dock.icon_name = &"Script"
	_dock.force_show_icon = true

	_content = DOCK_CONTENT_SCRIPT.new()
	_content.setup(get_editor_interface())
	_content.name = "GodexContent"
	_dock.add_child(_content)
	add_dock(_dock)

	_toolbar_button = Button.new()
	_toolbar_button.text = "Godex"
	_toolbar_button.tooltip_text = "Open and focus Godex"
	_toolbar_button.flat = true
	_toolbar_button.icon = get_editor_interface().get_base_control().get_theme_icon(
		"Script",
		"EditorIcons"
	)
	_toolbar_button.pressed.connect(_on_toolbar_button_pressed)
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, _toolbar_button)


func _exit_tree() -> void:
	if is_instance_valid(_toolbar_button):
		remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, _toolbar_button)
		_toolbar_button.queue_free()

	if is_instance_valid(_content) and _content.has_method("shutdown"):
		_content.shutdown()

	if is_instance_valid(_dock):
		remove_dock(_dock)
		_dock.queue_free()

	_content = null
	_dock = null
	_toolbar_button = null


func _on_toolbar_button_pressed() -> void:
	if is_instance_valid(_dock):
		_dock.make_visible()
	if is_instance_valid(_content) and _content.has_method("focus_input"):
		_content.call_deferred("focus_input")
