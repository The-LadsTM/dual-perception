@tool
extends VBoxContainer

const CONFIG_PATH := "user://godex.cfg"
const LEGACY_CONFIG_PATH := "user://codex_dock.cfg"
const CONFIG_SECTION := "godex"
const LEGACY_CONFIG_SECTION := "codex"
const COMPOSER_CONFIG_SECTION := "composer"
const CLIENT_NAME := "godex"
const CLIENT_VERSION := "1.0.0"
const AUTO_RECONNECT_DELAYS_MS := [1000, 2000, 5000, 10000, 30000]
const STDOUT_READ_BUDGET_BYTES := 512 * 1024
const STDOUT_PROCESS_BUDGET_MS := 8
const IMAGE_SOURCE_TEXT_SCAN_LIMIT := 64 * 1024
const RUN_SCENE_STATUS_REFRESH_MS := 250
const IMAGE_PATH_PATTERN := (
	"(?:res://|file://|https?://|[A-Za-z]:[\\\\/]|/)"
	+ "[^\\s\\\"'<>\\)]+"
	+ "\\.(?:png|jpe?g|webp|svg|bmp|tga)"
	+ "(?:\\?[^\\s\\\"'<>\\)]*)?"
)
const IMAGE_EXTENSIONS := [
	"png",
	"jpg",
	"jpeg",
	"webp",
	"svg",
	"bmp",
	"tga",
]
const RoundHistoryRailScript := preload(
	"res://addons/godex/round_history_rail.gd"
)

enum ThreadAction {
	RENAME = 1,
	FORK = 2,
	ARCHIVE_OR_RESTORE = 3,
	TOGGLE_ARCHIVED = 4,
}

enum ToolAction {
	REVIEW_UNCOMMITTED = 1,
	COMPACT_CONTEXT = 2,
	MCP_STATUS = 3,
	RECONNECT = 4,
	SETTINGS = 5,
}

enum ConnectionState {
	DISCONNECTED,
	STARTING,
	STARTING_THREAD,
	READY,
	TURN_RUNNING,
	ERROR,
}

var _state := ConnectionState.DISCONNECTED
var _process_id := -1
var _stdio: FileAccess
var _stderr: FileAccess
var _stdout_bytes := PackedByteArray()
var _stdout_scan_offset := 0
var _stderr_text := ""
var _auto_reconnect_pending := false
var _auto_reconnect_attempt := 0
var _auto_reconnect_at_msec := 0
var _reconnect_restore_thread_id := ""
var _auto_reconnect_enabled := true
var _auto_reconnect_max_attempts := 5
var _connection_events := PackedStringArray()

var _next_request_id := 1
var _requests: Dictionary = {}
var _thread_id := ""
var _turn_id := ""
var _pending_prompts: Array[Dictionary] = []
var _followup_queue: Array[Dictionary] = []
var _drafts_by_thread: Dictionary = {}
var _followup_queues_by_thread: Dictionary = {}
var _prompt_history_by_thread: Dictionary = {}
var _active_composer_thread_id := ""
var _composer_state_updates_suspended := false
var _prompt_history_cursor := -1
var _prompt_history_draft := ""
var _prompt_history_popup_items := PackedStringArray()
var _assistant_received_text := false
var _updating_thread_selector := false
var _pending_resume_thread_id := ""
var _pending_delete_thread_id := ""
var _pending_delete_thread_title := ""
var _pending_rename_thread_id := ""
var _pending_rename_title := ""
var _pending_archive_thread_id := ""
var _pending_unarchive_thread_id := ""
var _resume_after_thread_list_id := ""
var _thread_list_request_pending := false
var _thread_list_reload_queued := false
var _show_archived_threads := false
var _thread_list_cache: Array = []
var _create_new_after_connect := false
var _updating_model_selector := false
var _selected_model_id := ""
var _model_list_request_pending := false
var _waiting_for_initial_model_list := false
var _model_list_loaded := false
var _model_list_items: Array = []
var _model_catalog: Dictionary = {}
var _codex_default_model_id := ""
var _updating_effort_selector := false
var _selected_reasoning_effort := ""
var _attached_skill: Dictionary = {}
var _refresh_history_after_turn := false
var _editor_interface: EditorInterface
var _current_turn_diff := ""
var _server_request_queue: Array[Dictionary] = []
var _active_server_request: Dictionary = {}
var _question_fields: Array[Dictionary] = []
var _skills: Array[Dictionary] = []
var _rate_limits_request_pending := false
var _rate_limit_snapshot: Dictionary = {}
var _rate_limit_error := ""
var _image_path_regex := RegEx.new()
var _image_path_regex_ready := false
var _transcript_entries: Array[Dictionary] = []
var _assistant_stream_text := ""
var _next_transcript_entry_id := 1
var _tool_entry_by_item_id: Dictionary = {}
var _transcript_render_pending := false
var _transcript_render_suspended := false
var _last_transcript_render_msec := 0
var _transcript_render_has_new_content := false
var _transcript_render_generation := 0
var _transcript_following := true
var _transcript_has_unseen_content := false
var _transcript_scroll_tracking_suspended := false
var _next_transcript_scroll_restore := -1.0
var _plan_entries: Array[Dictionary] = []
var _plan_explanation := ""
var _plan_text := ""
var _plan_stream_text := ""
var _plan_expanded := true
var _search_match_rounds := PackedInt32Array()
var _search_match_index := -1

var _status_dot: Label
var _status_label: Label
var _rate_limit_button: Button
var _path_edit: LineEdit
var _reconnect_button: Button
var _thread_selector: OptionButton
var _delete_thread_button: Button
var _new_thread_button: Button
var _delete_confirmation: ConfirmationDialog
var _thread_actions_button: MenuButton
var _rename_thread_dialog: ConfirmationDialog
var _rename_thread_edit: LineEdit
var _model_selector: OptionButton
var _refresh_models_button: Button
var _effort_selector: OptionButton
var _skills_selector: OptionButton
var _refresh_skills_button: Button
var _tools_button: MenuButton
var _inventory_dialog: AcceptDialog
var _inventory_view: TextEdit
var _compact_confirmation: ConfirmationDialog
var _run_scene_button: Button
var _allow_edits_check: Button
var _policy_label: Label
var _diff_button: Button
var _diff_dialog: AcceptDialog
var _diff_tree: Tree
var _diff_view: TextEdit
var _diff_open_button: Button
var _diff_accept_button: Button
var _diff_revert_button: Button
var _diff_copy_button: Button
var _diff_run_button: Button
var _diff_revert_confirmation: ConfirmationDialog
var _diff_files: Array[Dictionary] = []
var _diff_resolution: Dictionary = {}
var _pending_revert_patch := ""
var _pending_revert_key := ""
var _pending_revert_label := ""
var _settings_dialog: ConfirmationDialog
var _settings_path_edit: LineEdit
var _settings_allow_edits_check: CheckButton
var _settings_model_selector: OptionButton
var _settings_effort_selector: OptionButton
var _settings_auto_reconnect_check: CheckButton
var _settings_max_reconnect_spin: SpinBox
var _settings_status_view: TextEdit
var _settings_reconnect_button: Button
var _settings_export_button: Button
var _settings_import_button: Button
var _settings_file_dialog: FileDialog
var _settings_file_mode := ""
var _next_settings_status_refresh_msec := 0
var _next_run_scene_status_refresh_msec := 0
var _run_scene_button_state_initialized := false
var _run_scene_button_is_playing := false
var _approval_dialog: ConfirmationDialog
var _approval_details: TextEdit
var _approval_session_button: Button
var _approval_cancel_turn_button: Button
var _question_dialog: ConfirmationDialog
var _question_container: VBoxContainer
var _request_auto_timer: Timer
var _plan_panel: PanelContainer
var _plan_header: Button
var _plan_body: VBoxContainer
var _plan_explanation_label: Label
var _plan_steps: VBoxContainer
var _transcript_shell: Control
var _transcript: RichTextLabel
var _round_history_rail: Control
var _round_preview: PanelContainer
var _round_preview_title: Label
var _round_preview_body: Label
var _round_preview_meta: Label
var _round_summaries: Array[Dictionary] = []
var _round_active_index := -1
var _round_preview_index := -1
var _copy_toast: PanelContainer
var _copy_toast_label: Label
var _copy_toast_timer: Timer
var _copy_toast_tween: Tween
var _new_content_button: Button
var _search_panel: PanelContainer
var _search_edit: LineEdit
var _search_count_label: Label
var _followup_queue_panel: PanelContainer
var _followup_queue_title: Label
var _followup_queue_scroll: ScrollContainer
var _followup_queue_items: VBoxContainer
var _input: TextEdit
var _composer_save_timer: Timer
var _history_button: MenuButton
var _queue_button: Button
var _send_button: Button
var _interrupt_button: Button
var _image_preview_dialog: AcceptDialog
var _image_preview_texture: TextureRect
var _image_preview_path_label: Label
var _image_preview_save_button: Button
var _image_preview_open_button: Button
var _image_preview_copy_button: Button
var _image_save_dialog: FileDialog
var _active_image_source := ""
var _pending_image_save_source := ""
var _image_texture_cache: Dictionary = {}
var _image_texture_cache_order := PackedStringArray()
var _image_load_queue: Array[String] = []
var _image_load_queued_keys: Dictionary = {}
var _image_load_scheduled := false
var _image_failed_sources: Dictionary = {}
var _history_image_sources_on_demand: Dictionary = {}
var _collecting_history_images := false
var _image_source_by_token: Dictionary = {}
var _image_token_by_cache_key: Dictionary = {}
var _next_image_token := 1


func setup(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface


func _editor_icon(icon_name: StringName) -> Texture2D:
	if _editor_interface == null:
		return null
	var base_control := _editor_interface.get_base_control()
	if (
		is_instance_valid(base_control)
		and base_control.has_theme_icon(icon_name, &"EditorIcons")
	):
		return base_control.get_theme_icon(icon_name, &"EditorIcons")
	return null


func _configure_icon_button(
	button: Button,
	icon_name: StringName,
	fallback_text: String,
	tooltip: String
) -> void:
	var icon_texture := _editor_icon(icon_name)
	button.icon = icon_texture
	button.text = "" if icon_texture != null else fallback_text
	button.tooltip_text = tooltip
	button.flat = true
	button.custom_minimum_size = Vector2(32.0, 32.0)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _ready() -> void:
	_image_path_regex_ready = _image_path_regex.compile(IMAGE_PATH_PATTERN) == OK
	_build_ui()
	_load_settings()
	set_process(true)

	if DisplayServer.get_name() != "headless":
		call_deferred("_connect_server")


func _build_ui() -> void:
	name = "Godex"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(300.0, 280.0)
	add_theme_constant_override("separation", 8)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 6)
	add_child(status_row)

	_status_dot = Label.new()
	_status_dot.text = "●"
	_status_dot.tooltip_text = "Codex App Server status"
	status_row.add_child(_status_dot)

	_status_label = Label.new()
	_status_label.text = "Disconnected"
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.clip_text = true
	status_row.add_child(_status_label)

	_rate_limit_button = Button.new()
	_rate_limit_button.text = "Usage --"
	_rate_limit_button.tooltip_text = "Codex account usage; click for details"
	_rate_limit_button.flat = true
	_rate_limit_button.pressed.connect(_show_rate_limit_details)
	status_row.add_child(_rate_limit_button)

	var conversation_row := HBoxContainer.new()
	conversation_row.add_theme_constant_override("separation", 6)
	add_child(conversation_row)

	_thread_selector = OptionButton.new()
	_thread_selector.tooltip_text = "Select and resume a conversation for this project"
	_thread_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_thread_selector.custom_minimum_size = Vector2(100.0, 0.0)
	_thread_selector.fit_to_longest_item = false
	_thread_selector.item_selected.connect(_on_thread_selected)
	conversation_row.add_child(_thread_selector)

	_delete_thread_button = Button.new()
	_configure_icon_button(
		_delete_thread_button,
		&"Remove",
		"×",
		"Delete the selected conversation"
	)
	_delete_thread_button.pressed.connect(_on_delete_thread_pressed)
	conversation_row.add_child(_delete_thread_button)

	_new_thread_button = Button.new()
	_configure_icon_button(_new_thread_button, &"Add", "+", "Create a new Godex conversation")
	_new_thread_button.pressed.connect(_on_new_thread_pressed)
	conversation_row.add_child(_new_thread_button)

	_set_thread_selector_placeholder("Loading conversations…")

	_thread_actions_button = MenuButton.new()
	_configure_icon_button(
		_thread_actions_button,
		&"GuiDropdown",
		"☰",
		"Conversation actions"
	)
	var thread_actions_popup := _thread_actions_button.get_popup()
	thread_actions_popup.add_item("Rename…", ThreadAction.RENAME)
	thread_actions_popup.add_item("Fork", ThreadAction.FORK)
	thread_actions_popup.add_item("Archive", ThreadAction.ARCHIVE_OR_RESTORE)
	thread_actions_popup.add_separator()
	thread_actions_popup.add_item("View archive", ThreadAction.TOGGLE_ARCHIVED)
	thread_actions_popup.id_pressed.connect(_on_thread_action_selected)
	thread_actions_popup.about_to_popup.connect(_update_thread_actions_menu)
	conversation_row.add_child(_thread_actions_button)

	# Keep connection configuration available to the backend without occupying
	# a permanent toolbar row. Manual reconnect lives in the Tools menu.
	_path_edit = LineEdit.new()
	_path_edit.placeholder_text = "Codex executable path"
	_path_edit.tooltip_text = "Absolute path to the local codex.exe or codex executable"
	_path_edit.visible = false
	_path_edit.text_submitted.connect(_on_executable_path_submitted)
	_path_edit.focus_exited.connect(_save_settings)
	add_child(_path_edit)

	_reconnect_button = Button.new()
	_reconnect_button.text = "Connect"
	_reconnect_button.tooltip_text = "Reconnect to Codex using this path"
	_reconnect_button.visible = false
	_reconnect_button.pressed.connect(_on_reconnect_pressed)
	add_child(_reconnect_button)

	_policy_label = Label.new()
	_policy_label.visible = false
	add_child(_policy_label)

	var separator := HSeparator.new()
	add_child(separator)

	_build_plan_panel()

	_transcript_shell = Control.new()
	_transcript_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_transcript_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_transcript_shell.custom_minimum_size = Vector2(0.0, 160.0)
	_transcript_shell.resized.connect(_on_transcript_shell_resized)
	add_child(_transcript_shell)

	_transcript = RichTextLabel.new()
	_transcript.bbcode_enabled = true
	_transcript.selection_enabled = true
	_transcript.context_menu_enabled = true
	_transcript.scroll_active = true
	_transcript.scroll_following = false
	_transcript.meta_clicked.connect(_on_transcript_meta_clicked)
	_transcript.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transcript.offset_right = -30.0
	_transcript_shell.add_child(_transcript)
	_transcript.get_v_scroll_bar().value_changed.connect(
		_on_transcript_scroll_changed
	)

	_round_history_rail = RoundHistoryRailScript.new()
	_round_history_rail.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_round_history_rail.offset_left = -28.0
	_round_history_rail.offset_right = 0.0
	_round_history_rail.connect(
		"round_hovered",
		Callable(self, "_on_round_history_hovered")
	)
	_round_history_rail.connect(
		"round_unhovered",
		Callable(self, "_on_round_history_unhovered")
	)
	_round_history_rail.connect(
		"round_activated",
		Callable(self, "_on_round_history_activated")
	)
	_transcript_shell.add_child(_round_history_rail)
	_build_round_history_preview()
	_build_copy_toast()
	_build_new_content_button()
	_build_search_panel()
	_build_followup_queue_panel()

	_append_system_message(
		"Godex is loaded. Once connected, ask about the project, edit scripts, or run checks."
	)

	_input = TextEdit.new()
	_input.placeholder_text = "Ask Godex… (Enter to send, Shift/Ctrl+Enter for a newline)"
	_input.custom_minimum_size = Vector2(0.0, 82.0)
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.gui_input.connect(_on_input_gui_input)
	_input.text_changed.connect(_on_input_text_changed)
	add_child(_input)

	_composer_save_timer = Timer.new()
	_composer_save_timer.one_shot = true
	_composer_save_timer.wait_time = 0.4
	_composer_save_timer.timeout.connect(_persist_composer_state)
	add_child(_composer_save_timer)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 2)
	add_child(action_row)

	_allow_edits_check = Button.new()
	_allow_edits_check.toggle_mode = true
	_allow_edits_check.toggled.connect(_on_allow_edits_toggled)
	_configure_icon_button(
		_allow_edits_check,
		&"Edit",
		"✎",
		"Project edit permission"
	)
	action_row.add_child(_allow_edits_check)

	_model_selector = OptionButton.new()
	_model_selector.fit_to_longest_item = false
	_model_selector.item_selected.connect(_on_model_selected)
	_configure_icon_button(
		_model_selector,
		&"Script",
		"◆",
		"Model: syncing…"
	)
	action_row.add_child(_model_selector)
	_set_model_selector_placeholder("Syncing models…")

	_effort_selector = OptionButton.new()
	_effort_selector.fit_to_longest_item = false
	_effort_selector.item_selected.connect(_on_effort_selected)
	_configure_icon_button(
		_effort_selector,
		&"Time",
		"◷",
		"Reasoning effort: syncing…"
	)
	action_row.add_child(_effort_selector)
	_set_effort_selector_placeholder("Reasoning effort")

	_skills_selector = OptionButton.new()
	_skills_selector.fit_to_longest_item = false
	_skills_selector.allow_reselect = true
	_skills_selector.item_selected.connect(_on_skill_selected)
	_configure_icon_button(
		_skills_selector,
		&"RichTextEffect",
		"✦",
		"Skill: syncing…"
	)
	action_row.add_child(_skills_selector)
	_set_skills_placeholder("Skill")

	_tools_button = MenuButton.new()
	_configure_icon_button(_tools_button, &"Tools", "⋯", "Tools")
	var tools_popup := _tools_button.get_popup()
	tools_popup.add_item("Review uncommitted changes", ToolAction.REVIEW_UNCOMMITTED)
	tools_popup.add_item("Compact conversation context…", ToolAction.COMPACT_CONTEXT)
	tools_popup.add_separator()
	tools_popup.add_item("MCP status", ToolAction.MCP_STATUS)
	tools_popup.add_item("Reconnect Codex", ToolAction.RECONNECT)
	tools_popup.add_separator()
	tools_popup.add_item("Settings and connection status…", ToolAction.SETTINGS)
	tools_popup.id_pressed.connect(_on_tool_action_selected)
	tools_popup.about_to_popup.connect(_update_tools_menu)
	action_row.add_child(_tools_button)

	_history_button = MenuButton.new()
	_configure_icon_button(
		_history_button,
		&"History",
		"↶",
		"Prompt history (Alt+↑ / Alt+↓)"
	)
	var history_popup := _history_button.get_popup()
	history_popup.about_to_popup.connect(_populate_prompt_history_menu)
	history_popup.id_pressed.connect(_on_prompt_history_selected)
	action_row.add_child(_history_button)

	_run_scene_button = Button.new()
	_configure_icon_button(_run_scene_button, &"Play", "▶", "Run the current scene")
	_run_scene_button.pressed.connect(_toggle_current_scene)
	action_row.add_child(_run_scene_button)

	_diff_button = Button.new()
	_configure_icon_button(
		_diff_button,
		&"CodeHighlighter",
		"±",
		"No project diff is available"
	)
	_diff_button.disabled = true
	_diff_button.pressed.connect(_show_current_diff)
	action_row.add_child(_diff_button)

	var action_spacer := Control.new()
	action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(action_spacer)

	_interrupt_button = Button.new()
	_configure_icon_button(_interrupt_button, &"Stop", "■", "Interrupt the current Godex turn")
	_interrupt_button.pressed.connect(_on_interrupt_pressed)
	action_row.add_child(_interrupt_button)

	_queue_button = Button.new()
	_configure_icon_button(
		_queue_button,
		&"MoveUp",
		"⇧",
		"Queue for the next turn (Ctrl+Shift+Enter)"
	)
	_queue_button.visible = false
	_queue_button.pressed.connect(_queue_current_input)
	action_row.add_child(_queue_button)

	_send_button = Button.new()
	_configure_icon_button(_send_button, &"ArrowRight", "➤", "Send message")
	_send_button.pressed.connect(_send_current_input)
	action_row.add_child(_send_button)

	_delete_confirmation = ConfirmationDialog.new()
	_delete_confirmation.title = "Delete conversation"
	_delete_confirmation.dialog_text = "Delete this conversation permanently? This action cannot be undone."
	_delete_confirmation.confirmed.connect(_confirm_delete_thread)
	_delete_confirmation.canceled.connect(_cancel_delete_thread)
	add_child(_delete_confirmation)
	_delete_confirmation.get_ok_button().text = "Delete"
	_delete_confirmation.get_cancel_button().text = "Cancel"

	_build_diff_dialog()
	_build_image_preview_dialog()
	_build_settings_dialog()
	_build_approval_dialog()
	_build_question_dialog()
	_build_rename_thread_dialog()
	_build_inventory_dialog()
	_build_compact_confirmation()

	_set_state(ConnectionState.DISCONNECTED, "Disconnected")


func _build_plan_panel() -> void:
	_plan_panel = PanelContainer.new()
	_plan_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.09, 0.10, 0.125, 0.92)
	panel_style.border_color = Color(0.25, 0.29, 0.36, 0.85)
	panel_style.set_border_width_all(1)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 8.0
	panel_style.content_margin_top = 4.0
	panel_style.content_margin_right = 8.0
	panel_style.content_margin_bottom = 6.0
	_plan_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_plan_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	_plan_panel.add_child(content)

	_plan_header = Button.new()
	_plan_header.text = "▾ Plan"
	_plan_header.flat = true
	_plan_header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_plan_header.tooltip_text = "Expand or collapse the current Godex task plan"
	_plan_header.add_theme_font_size_override("font_size", 13)
	_plan_header.pressed.connect(_toggle_plan_panel)
	content.add_child(_plan_header)

	_plan_body = VBoxContainer.new()
	_plan_body.add_theme_constant_override("separation", 5)
	content.add_child(_plan_body)

	_plan_explanation_label = Label.new()
	_plan_explanation_label.visible = false
	_plan_explanation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_plan_explanation_label.max_lines_visible = 3
	_plan_explanation_label.add_theme_font_size_override("font_size", 12)
	_plan_explanation_label.add_theme_color_override(
		"font_color",
		Color(0.66, 0.70, 0.78)
	)
	_plan_body.add_child(_plan_explanation_label)

	_plan_steps = VBoxContainer.new()
	_plan_steps.add_theme_constant_override("separation", 3)
	_plan_body.add_child(_plan_steps)


func _build_round_history_preview() -> void:
	_round_preview = PanelContainer.new()
	_round_preview.visible = false
	_round_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_round_preview.z_index = 100
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.105, 0.115, 0.14, 0.98)
	preview_style.border_color = Color(0.30, 0.33, 0.39, 0.90)
	preview_style.set_border_width_all(1)
	preview_style.corner_radius_top_left = 10
	preview_style.corner_radius_top_right = 10
	preview_style.corner_radius_bottom_left = 10
	preview_style.corner_radius_bottom_right = 10
	preview_style.content_margin_left = 12.0
	preview_style.content_margin_top = 10.0
	preview_style.content_margin_right = 12.0
	preview_style.content_margin_bottom = 10.0
	_round_preview.add_theme_stylebox_override("panel", preview_style)
	_transcript_shell.add_child(_round_preview)

	var preview_content := VBoxContainer.new()
	preview_content.add_theme_constant_override("separation", 6)
	_round_preview.add_child(preview_content)

	_round_preview_title = Label.new()
	_round_preview_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_round_preview_title.max_lines_visible = 2
	_round_preview_title.add_theme_font_size_override("font_size", 14)
	_round_preview_title.add_theme_color_override(
		"font_color",
		Color(0.95, 0.96, 0.99)
	)
	preview_content.add_child(_round_preview_title)

	_round_preview_body = Label.new()
	_round_preview_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_round_preview_body.max_lines_visible = 3
	_round_preview_body.add_theme_font_size_override("font_size", 13)
	_round_preview_body.add_theme_color_override(
		"font_color",
		Color(0.72, 0.75, 0.81)
	)
	preview_content.add_child(_round_preview_body)

	_round_preview_meta = Label.new()
	_round_preview_meta.clip_text = true
	_round_preview_meta.add_theme_font_size_override("font_size", 11)
	_round_preview_meta.add_theme_color_override(
		"font_color",
		Color(0.53, 0.57, 0.65)
	)
	preview_content.add_child(_round_preview_meta)


func _build_copy_toast() -> void:
	_copy_toast = PanelContainer.new()
	_copy_toast.visible = false
	_copy_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_copy_toast.z_index = 120
	var toast_style := StyleBoxFlat.new()
	toast_style.bg_color = Color(0.13, 0.15, 0.19, 0.98)
	toast_style.border_color = Color(0.36, 0.66, 1.0, 0.95)
	toast_style.set_border_width_all(1)
	toast_style.corner_radius_top_left = 7
	toast_style.corner_radius_top_right = 7
	toast_style.corner_radius_bottom_left = 7
	toast_style.corner_radius_bottom_right = 7
	toast_style.content_margin_left = 10.0
	toast_style.content_margin_top = 6.0
	toast_style.content_margin_right = 10.0
	toast_style.content_margin_bottom = 6.0
	_copy_toast.add_theme_stylebox_override("panel", toast_style)
	_transcript_shell.add_child(_copy_toast)

	_copy_toast_label = Label.new()
	_copy_toast_label.text = "Copied"
	_copy_toast_label.add_theme_font_size_override("font_size", 12)
	_copy_toast_label.add_theme_color_override(
		"font_color",
		Color(0.94, 0.97, 1.0)
	)
	_copy_toast.add_child(_copy_toast_label)

	_copy_toast_timer = Timer.new()
	_copy_toast_timer.one_shot = true
	_copy_toast_timer.wait_time = 1.0
	_copy_toast_timer.timeout.connect(_hide_copy_toast)
	add_child(_copy_toast_timer)


func _build_new_content_button() -> void:
	_new_content_button = Button.new()
	_new_content_button.text = "↓ Jump to latest"
	_new_content_button.visible = false
	_new_content_button.z_index = 115
	_new_content_button.tooltip_text = "Jump to the bottom of the conversation"
	_new_content_button.add_theme_font_size_override("font_size", 12)
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color(0.14, 0.19, 0.28, 0.98)
	button_style.border_color = Color(0.35, 0.65, 1.0, 0.95)
	button_style.set_border_width_all(1)
	button_style.corner_radius_top_left = 14
	button_style.corner_radius_top_right = 14
	button_style.corner_radius_bottom_left = 14
	button_style.corner_radius_bottom_right = 14
	button_style.content_margin_left = 12.0
	button_style.content_margin_top = 5.0
	button_style.content_margin_right = 12.0
	button_style.content_margin_bottom = 5.0
	_new_content_button.add_theme_stylebox_override("normal", button_style)
	var hover_style := button_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.20, 0.31, 0.48, 1.0)
	_new_content_button.add_theme_stylebox_override("hover", hover_style)
	_new_content_button.pressed.connect(_jump_to_latest)
	_transcript_shell.add_child(_new_content_button)


func _build_search_panel() -> void:
	_search_panel = PanelContainer.new()
	_search_panel.visible = false
	_search_panel.z_index = 130
	var search_style := StyleBoxFlat.new()
	search_style.bg_color = Color(0.095, 0.105, 0.13, 0.98)
	search_style.border_color = Color(0.30, 0.34, 0.41, 0.95)
	search_style.set_border_width_all(1)
	search_style.corner_radius_top_left = 7
	search_style.corner_radius_top_right = 7
	search_style.corner_radius_bottom_left = 7
	search_style.corner_radius_bottom_right = 7
	search_style.content_margin_left = 6.0
	search_style.content_margin_top = 5.0
	search_style.content_margin_right = 4.0
	search_style.content_margin_bottom = 5.0
	_search_panel.add_theme_stylebox_override("panel", search_style)
	_transcript_shell.add_child(_search_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	_search_panel.add_child(row)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Search this conversation"
	_search_edit.custom_minimum_size = Vector2(150.0, 0.0)
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.text_changed.connect(_on_search_text_changed)
	_search_edit.gui_input.connect(_on_search_gui_input)
	row.add_child(_search_edit)

	_search_count_label = Label.new()
	_search_count_label.text = "0 / 0"
	_search_count_label.custom_minimum_size = Vector2(48.0, 0.0)
	_search_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_search_count_label.add_theme_font_size_override("font_size", 11)
	_search_count_label.add_theme_color_override(
		"font_color",
		Color(0.64, 0.68, 0.75)
	)
	row.add_child(_search_count_label)

	for search_action in [
		{"text": "↑", "tooltip": "Previous match", "callback": "_previous_search_match"},
		{"text": "↓", "tooltip": "Next match", "callback": "_next_search_match"},
		{"text": "×", "tooltip": "Close search", "callback": "_close_search"},
	]:
		var action_button := Button.new()
		action_button.text = str(search_action["text"])
		action_button.flat = true
		action_button.custom_minimum_size = Vector2(25.0, 25.0)
		action_button.tooltip_text = str(search_action["tooltip"])
		action_button.pressed.connect(
			Callable(self, str(search_action["callback"]))
		)
		row.add_child(action_button)


func _build_followup_queue_panel() -> void:
	_followup_queue_panel = PanelContainer.new()
	_followup_queue_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.09, 0.105, 0.135, 0.96)
	panel_style.border_color = Color(0.27, 0.32, 0.40, 0.92)
	panel_style.set_border_width_all(1)
	panel_style.corner_radius_top_left = 7
	panel_style.corner_radius_top_right = 7
	panel_style.corner_radius_bottom_left = 7
	panel_style.corner_radius_bottom_right = 7
	panel_style.content_margin_left = 7.0
	panel_style.content_margin_top = 6.0
	panel_style.content_margin_right = 7.0
	panel_style.content_margin_bottom = 6.0
	_followup_queue_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_followup_queue_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	_followup_queue_panel.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	content.add_child(header)

	_followup_queue_title = Label.new()
	_followup_queue_title.text = "Queued"
	_followup_queue_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_followup_queue_title.add_theme_font_size_override("font_size", 12)
	_followup_queue_title.add_theme_color_override(
		"font_color",
		Color(0.91, 0.93, 0.97)
	)
	header.add_child(_followup_queue_title)

	var queue_hint := Label.new()
	queue_hint.text = "Next turn"
	queue_hint.add_theme_font_size_override("font_size", 11)
	queue_hint.add_theme_color_override(
		"font_color",
		Color(0.55, 0.60, 0.69)
	)
	header.add_child(queue_hint)

	_followup_queue_scroll = ScrollContainer.new()
	_followup_queue_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(_followup_queue_scroll)

	_followup_queue_items = VBoxContainer.new()
	_followup_queue_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_followup_queue_items.add_theme_constant_override("separation", 3)
	_followup_queue_scroll.add_child(_followup_queue_items)


func _build_inventory_dialog() -> void:
	_inventory_dialog = AcceptDialog.new()
	_inventory_dialog.title = "Godex status"
	_inventory_dialog.get_ok_button().text = "Close"
	add_child(_inventory_dialog)

	_inventory_view = TextEdit.new()
	_inventory_view.editable = false
	_inventory_view.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_inventory_view.custom_minimum_size = Vector2(680.0, 430.0)
	_inventory_dialog.add_child(_inventory_view)


func _build_compact_confirmation() -> void:
	_compact_confirmation = ConfirmationDialog.new()
	_compact_confirmation.title = "Compact conversation context"
	_compact_confirmation.dialog_text = (
		"Godex will summarize earlier conversation content to free context space.\n\n"
		+ "The conversation remains available, but the model will primarily use the compacted summary afterward."
	)
	_compact_confirmation.get_ok_button().text = "Compact"
	_compact_confirmation.get_cancel_button().text = "Cancel"
	_compact_confirmation.confirmed.connect(_start_context_compaction)
	add_child(_compact_confirmation)


func _build_rename_thread_dialog() -> void:
	_rename_thread_dialog = ConfirmationDialog.new()
	_rename_thread_dialog.title = "Rename conversation"
	_rename_thread_dialog.get_ok_button().text = "Save"
	_rename_thread_dialog.get_cancel_button().text = "Cancel"
	_rename_thread_dialog.confirmed.connect(_confirm_rename_thread)
	_rename_thread_dialog.canceled.connect(_cancel_rename_thread)
	add_child(_rename_thread_dialog)

	_rename_thread_edit = LineEdit.new()
	_rename_thread_edit.placeholder_text = "Enter a new conversation name"
	_rename_thread_edit.custom_minimum_size = Vector2(430.0, 0.0)
	_rename_thread_edit.text_submitted.connect(_on_rename_thread_submitted)
	_rename_thread_dialog.add_child(_rename_thread_edit)


func _build_diff_dialog() -> void:
	_diff_dialog = AcceptDialog.new()
	_diff_dialog.title = "Godex project diff"
	_diff_dialog.get_ok_button().text = "Close"
	add_child(_diff_dialog)

	var diff_layout := VBoxContainer.new()
	diff_layout.add_theme_constant_override("separation", 8)
	_diff_dialog.add_child(diff_layout)

	var diff_split := HSplitContainer.new()
	diff_split.custom_minimum_size = Vector2(920.0, 520.0)
	diff_split.split_offset = 300
	diff_layout.add_child(diff_split)

	_diff_tree = Tree.new()
	_diff_tree.hide_root = true
	_diff_tree.columns = 2
	_diff_tree.set_column_title(0, "File / Hunk")
	_diff_tree.set_column_title(1, "Status")
	_diff_tree.set_column_titles_visible(true)
	_diff_tree.set_column_expand(0, true)
	_diff_tree.set_column_expand(1, false)
	_diff_tree.set_column_custom_minimum_width(1, 80)
	_diff_tree.item_selected.connect(_on_diff_tree_selection_changed)
	diff_split.add_child(_diff_tree)

	_diff_view = TextEdit.new()
	_diff_view.editable = false
	_diff_view.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	_diff_view.custom_minimum_size = Vector2(580.0, 500.0)
	diff_split.add_child(_diff_view)

	var diff_actions := HBoxContainer.new()
	diff_actions.add_theme_constant_override("separation", 6)
	diff_layout.add_child(diff_actions)

	_diff_open_button = Button.new()
	_diff_open_button.text = "Open file"
	_diff_open_button.pressed.connect(_open_selected_diff_file)
	diff_actions.add_child(_diff_open_button)

	_diff_copy_button = Button.new()
	_diff_copy_button.text = "Copy patch"
	_diff_copy_button.pressed.connect(_copy_selected_diff_patch)
	diff_actions.add_child(_diff_copy_button)

	_diff_accept_button = Button.new()
	_diff_accept_button.text = "Accept"
	_diff_accept_button.tooltip_text = "Keep the change and mark the selected file or hunk as accepted"
	_diff_accept_button.pressed.connect(_accept_selected_diff)
	diff_actions.add_child(_diff_accept_button)

	_diff_revert_button = Button.new()
	_diff_revert_button.text = "Revert"
	_diff_revert_button.tooltip_text = "Revert the selected file or hunk with a reverse patch"
	_diff_revert_button.pressed.connect(_request_revert_selected_diff)
	diff_actions.add_child(_diff_revert_button)

	var diff_action_spacer := Control.new()
	diff_action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diff_actions.add_child(diff_action_spacer)

	_diff_run_button = Button.new()
	_diff_run_button.text = "Run current scene"
	_diff_run_button.pressed.connect(_toggle_current_scene)
	diff_actions.add_child(_diff_run_button)

	_diff_revert_confirmation = ConfirmationDialog.new()
	_diff_revert_confirmation.title = "Revert Godex change"
	_diff_revert_confirmation.get_ok_button().text = "Revert change"
	_diff_revert_confirmation.get_cancel_button().text = "Cancel"
	_diff_revert_confirmation.confirmed.connect(_confirm_revert_selected_diff)
	add_child(_diff_revert_confirmation)


func _build_image_preview_dialog() -> void:
	_image_preview_dialog = AcceptDialog.new()
	_image_preview_dialog.title = "Image preview"
	_image_preview_dialog.get_ok_button().text = "Close"
	add_child(_image_preview_dialog)

	var preview_layout := VBoxContainer.new()
	preview_layout.add_theme_constant_override("separation", 8)
	_image_preview_dialog.add_child(preview_layout)

	_image_preview_texture = TextureRect.new()
	_image_preview_texture.custom_minimum_size = Vector2(820.0, 540.0)
	_image_preview_texture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_image_preview_texture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_image_preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image_preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_layout.add_child(_image_preview_texture)

	_image_preview_path_label = Label.new()
	_image_preview_path_label.clip_text = true
	_image_preview_path_label.add_theme_color_override(
		"font_color",
		Color(0.68, 0.72, 0.79)
	)
	preview_layout.add_child(_image_preview_path_label)

	var preview_actions := HBoxContainer.new()
	preview_actions.add_theme_constant_override("separation", 6)
	preview_layout.add_child(preview_actions)

	_image_preview_save_button = Button.new()
	_image_preview_save_button.text = "Save image…"
	_image_preview_save_button.pressed.connect(_save_active_image)
	preview_actions.add_child(_image_preview_save_button)

	_image_preview_open_button = Button.new()
	_image_preview_open_button.text = "Open location"
	_image_preview_open_button.pressed.connect(_open_active_image_location)
	preview_actions.add_child(_image_preview_open_button)

	_image_preview_copy_button = Button.new()
	_image_preview_copy_button.text = "Copy path"
	_image_preview_copy_button.pressed.connect(_copy_active_image_path)
	preview_actions.add_child(_image_preview_copy_button)

	_image_save_dialog = FileDialog.new()
	_image_save_dialog.title = "Save generated image"
	_image_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_image_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_image_save_dialog.filters = PackedStringArray(
		[
			"*.png ; PNG images",
			"*.jpg, *.jpeg ; JPEG images",
			"*.webp ; WebP images",
			"*.svg ; SVG images",
			"*.* ; All files",
		]
	)
	_image_save_dialog.file_selected.connect(_on_image_save_file_selected)
	add_child(_image_save_dialog)


func _build_settings_dialog() -> void:
	_settings_dialog = ConfirmationDialog.new()
	_settings_dialog.title = "Godex settings and connection status"
	_settings_dialog.get_ok_button().text = "Save"
	_settings_dialog.get_cancel_button().text = "Cancel"
	_settings_dialog.confirmed.connect(_apply_settings_dialog)
	add_child(_settings_dialog)

	var settings_layout := VBoxContainer.new()
	settings_layout.add_theme_constant_override("separation", 10)
	_settings_dialog.add_child(settings_layout)

	var settings_grid := GridContainer.new()
	settings_grid.columns = 2
	settings_grid.add_theme_constant_override("h_separation", 12)
	settings_grid.add_theme_constant_override("v_separation", 8)
	settings_layout.add_child(settings_grid)

	var path_label := Label.new()
	path_label.text = "Codex path"
	settings_grid.add_child(path_label)
	_settings_path_edit = LineEdit.new()
	_settings_path_edit.custom_minimum_size = Vector2(480.0, 0.0)
	settings_grid.add_child(_settings_path_edit)

	var permission_label := Label.new()
	permission_label.text = "Default permission"
	settings_grid.add_child(permission_label)
	_settings_allow_edits_check = CheckButton.new()
	_settings_allow_edits_check.text = "Allow changes to this project"
	settings_grid.add_child(_settings_allow_edits_check)

	var model_label := Label.new()
	model_label.text = "Default model"
	settings_grid.add_child(model_label)
	_settings_model_selector = OptionButton.new()
	_settings_model_selector.fit_to_longest_item = false
	_settings_model_selector.item_selected.connect(_on_settings_model_selected)
	settings_grid.add_child(_settings_model_selector)

	var effort_label := Label.new()
	effort_label.text = "Default reasoning effort"
	settings_grid.add_child(effort_label)
	_settings_effort_selector = OptionButton.new()
	_settings_effort_selector.fit_to_longest_item = false
	settings_grid.add_child(_settings_effort_selector)

	var reconnect_label := Label.new()
	reconnect_label.text = "Automatic reconnect"
	settings_grid.add_child(reconnect_label)
	var reconnect_row := HBoxContainer.new()
	_settings_auto_reconnect_check = CheckButton.new()
	_settings_auto_reconnect_check.text = "Enabled"
	reconnect_row.add_child(_settings_auto_reconnect_check)
	var attempts_label := Label.new()
	attempts_label.text = "Maximum retries"
	reconnect_row.add_child(attempts_label)
	_settings_max_reconnect_spin = SpinBox.new()
	_settings_max_reconnect_spin.min_value = 1
	_settings_max_reconnect_spin.max_value = 20
	_settings_max_reconnect_spin.step = 1
	reconnect_row.add_child(_settings_max_reconnect_spin)
	settings_grid.add_child(reconnect_row)

	var status_label := Label.new()
	status_label.text = "Connection and diagnostics"
	settings_layout.add_child(status_label)
	_settings_status_view = TextEdit.new()
	_settings_status_view.editable = false
	_settings_status_view.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_settings_status_view.custom_minimum_size = Vector2(660.0, 220.0)
	settings_layout.add_child(_settings_status_view)

	var settings_actions := HBoxContainer.new()
	settings_actions.add_theme_constant_override("separation", 6)
	settings_layout.add_child(settings_actions)
	_settings_reconnect_button = Button.new()
	_settings_reconnect_button.text = "Save and reconnect"
	_settings_reconnect_button.pressed.connect(_apply_settings_and_reconnect)
	settings_actions.add_child(_settings_reconnect_button)
	_settings_export_button = Button.new()
	_settings_export_button.text = "Export settings…"
	_settings_export_button.pressed.connect(_export_settings)
	settings_actions.add_child(_settings_export_button)
	_settings_import_button = Button.new()
	_settings_import_button.text = "Import settings…"
	_settings_import_button.pressed.connect(_import_settings)
	settings_actions.add_child(_settings_import_button)

	_settings_file_dialog = FileDialog.new()
	_settings_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_settings_file_dialog.filters = PackedStringArray(
		["*.json ; Godex settings"]
	)
	_settings_file_dialog.file_selected.connect(_on_settings_file_selected)
	add_child(_settings_file_dialog)


func _build_approval_dialog() -> void:
	_approval_dialog = ConfirmationDialog.new()
	_approval_dialog.title = "Godex permission request"
	_approval_dialog.get_ok_button().text = "Allow once"
	_approval_dialog.get_cancel_button().text = "Decline"
	_approval_dialog.confirmed.connect(_approve_active_request_once)
	_approval_dialog.canceled.connect(_decline_active_request)
	_approval_dialog.custom_action.connect(_on_approval_custom_action)
	add_child(_approval_dialog)

	_approval_details = TextEdit.new()
	_approval_details.editable = false
	_approval_details.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_approval_details.custom_minimum_size = Vector2(620.0, 310.0)
	_approval_dialog.add_child(_approval_details)

	_approval_session_button = _approval_dialog.add_button(
		"Allow for this session",
		true,
		"accept_session"
	)
	_approval_cancel_turn_button = _approval_dialog.add_button(
		"Decline and stop",
		false,
		"cancel_turn"
	)


func _build_question_dialog() -> void:
	_question_dialog = ConfirmationDialog.new()
	_question_dialog.title = "Godex needs your answer"
	_question_dialog.get_ok_button().text = "Submit"
	_question_dialog.get_cancel_button().text = "Cancel"
	_question_dialog.confirmed.connect(_submit_question_answers)
	_question_dialog.canceled.connect(_cancel_question_answers)
	add_child(_question_dialog)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620.0, 380.0)
	_question_dialog.add_child(scroll)

	_question_container = VBoxContainer.new()
	_question_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_question_container.add_theme_constant_override("separation", 12)
	scroll.add_child(_question_container)

	_request_auto_timer = Timer.new()
	_request_auto_timer.one_shot = true
	_request_auto_timer.timeout.connect(_auto_resolve_question_request)
	add_child(_request_auto_timer)


func _load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(CONFIG_PATH)
	var settings_section := CONFIG_SECTION
	var loaded_legacy_settings := false
	if error != OK:
		error = config.load(LEGACY_CONFIG_PATH)
		settings_section = LEGACY_CONFIG_SECTION
		loaded_legacy_settings = error == OK
	if error == OK:
		_path_edit.text = str(config.get_value(settings_section, "executable_path", ""))
		_allow_edits_check.button_pressed = bool(
			config.get_value(settings_section, "allow_project_edits", true)
		)
		_selected_model_id = str(
			config.get_value(settings_section, "selected_model_id", "")
		)
		_selected_reasoning_effort = str(
			config.get_value(settings_section, "selected_reasoning_effort", "")
		)
		_auto_reconnect_enabled = bool(
			config.get_value(settings_section, "auto_reconnect_enabled", true)
		)
		_auto_reconnect_max_attempts = clampi(
			int(config.get_value(settings_section, "auto_reconnect_max_attempts", 5)),
			1,
			20
		)
		var drafts_value: Variant = config.get_value(
			COMPOSER_CONFIG_SECTION,
			"drafts_by_thread",
			{}
		)
		if typeof(drafts_value) == TYPE_DICTIONARY:
			_drafts_by_thread = (drafts_value as Dictionary).duplicate(true)
		var queues_value: Variant = config.get_value(
			COMPOSER_CONFIG_SECTION,
			"followup_queues_by_thread",
			{}
		)
		if typeof(queues_value) == TYPE_DICTIONARY:
			_followup_queues_by_thread = (
				(queues_value as Dictionary).duplicate(true)
			)
		var history_value: Variant = config.get_value(
			COMPOSER_CONFIG_SECTION,
			"prompt_history_by_thread",
			{}
		)
		if typeof(history_value) == TYPE_DICTIONARY:
			_prompt_history_by_thread = (
				(history_value as Dictionary).duplicate(true)
			)
	else:
		_allow_edits_check.button_pressed = true
		_selected_model_id = ""
		_selected_reasoning_effort = ""
		_auto_reconnect_enabled = true
		_auto_reconnect_max_attempts = 5
		_drafts_by_thread.clear()
		_followup_queues_by_thread.clear()
		_prompt_history_by_thread.clear()

	if _path_edit.text.strip_edges().is_empty():
		_path_edit.text = _find_codex_executable()

	_update_policy_label()
	_load_composer_state("")
	if loaded_legacy_settings:
		_save_settings()


func _save_settings() -> void:
	if (
		is_instance_valid(_input)
		and not _composer_state_updates_suspended
	):
		_store_current_composer_state_in_memory()
	var config := ConfigFile.new()
	config.set_value(CONFIG_SECTION, "executable_path", _path_edit.text.strip_edges())
	config.set_value(CONFIG_SECTION, "allow_project_edits", _allow_edits_check.button_pressed)
	config.set_value(CONFIG_SECTION, "selected_model_id", _selected_model_id)
	config.set_value(
		CONFIG_SECTION,
		"selected_reasoning_effort",
		_selected_reasoning_effort
	)
	config.set_value(
		CONFIG_SECTION,
		"auto_reconnect_enabled",
		_auto_reconnect_enabled
	)
	config.set_value(
		CONFIG_SECTION,
		"auto_reconnect_max_attempts",
		_auto_reconnect_max_attempts
	)
	config.set_value(
		COMPOSER_CONFIG_SECTION,
		"drafts_by_thread",
		_drafts_by_thread
	)
	config.set_value(
		COMPOSER_CONFIG_SECTION,
		"followup_queues_by_thread",
		_followup_queues_by_thread
	)
	config.set_value(
		COMPOSER_CONFIG_SECTION,
		"prompt_history_by_thread",
		_prompt_history_by_thread
	)
	var error := config.save(CONFIG_PATH)
	if error != OK:
		_append_error("Could not save Godex settings: %s" % error_string(error))


func _find_codex_executable(excluded_path := "") -> String:
	var environment_path := OS.get_environment("CODEX_PATH").strip_edges()
	if (
		not environment_path.is_empty()
		and environment_path != excluded_path
		and FileAccess.file_exists(environment_path)
	):
		return environment_path

	var candidates := PackedStringArray()
	var user_profile := OS.get_environment("USERPROFILE")
	var local_app_data := OS.get_environment("LOCALAPPDATA")
	var app_data := OS.get_environment("APPDATA")
	var home_directory := OS.get_environment("HOME")

	if OS.get_name() == "Windows":
		if not user_profile.is_empty():
			candidates.append(
				user_profile.path_join(".codex/plugins/.plugin-appserver/codex.exe")
			)
			candidates.append(user_profile.path_join(".codex/.sandbox-bin/codex.exe"))
		if not local_app_data.is_empty():
			candidates.append(
				local_app_data.path_join("Microsoft/WindowsApps/codex.exe")
			)
			var codex_bin_directory := local_app_data.path_join("OpenAI/Codex/bin")
			var newest_binary := _find_newest_nested_binary(
				codex_bin_directory,
				"codex.exe"
			)
			if not newest_binary.is_empty():
				candidates.append(newest_binary)
		if not app_data.is_empty():
			candidates.append(
				app_data.path_join(
					"npm/node_modules/@openai/codex/vendor/"
					+ "x86_64-pc-windows-msvc/codex/codex.exe"
				)
			)
	else:
		if not home_directory.is_empty():
			candidates.append(home_directory.path_join(".local/bin/codex"))
			candidates.append(home_directory.path_join(".codex/bin/codex"))
			candidates.append(home_directory.path_join(".npm-global/bin/codex"))
			candidates.append(home_directory.path_join(".local/share/pnpm/codex"))
		candidates.append("/usr/local/bin/codex")
		candidates.append("/opt/homebrew/bin/codex")
		if OS.get_name() == "macOS":
			candidates.append("/Applications/Codex.app/Contents/Resources/codex")

	for candidate in candidates:
		if candidate != excluded_path and FileAccess.file_exists(candidate):
			return candidate

	var executable_name := "codex.exe" if OS.get_name() == "Windows" else "codex"
	var path_value := OS.get_environment("PATH")
	var path_separator := ";" if OS.get_name() == "Windows" else ":"
	for directory in path_value.split(path_separator, false):
		var path_candidate := directory.strip_edges().path_join(executable_name)
		if path_candidate != excluded_path and FileAccess.file_exists(path_candidate):
			return path_candidate

	return ""


func _find_newest_nested_binary(base_directory: String, binary_name: String) -> String:
	if not DirAccess.dir_exists_absolute(base_directory):
		return ""

	var newest_path := ""
	var newest_time := 0
	for child_directory in DirAccess.get_directories_at(base_directory):
		var candidate := base_directory.path_join(child_directory).path_join(binary_name)
		if not FileAccess.file_exists(candidate):
			continue
		var modified_time := int(FileAccess.get_modified_time(candidate))
		if newest_path.is_empty() or modified_time > newest_time:
			newest_path = candidate
			newest_time = modified_time

	return newest_path


func _connect_server(auto_reconnect := false) -> void:
	var thread_to_restore := _reconnect_restore_thread_id
	if thread_to_restore.is_empty() and not _thread_id.is_empty():
		thread_to_restore = _thread_id
	_reconnect_restore_thread_id = thread_to_restore
	_auto_reconnect_pending = false
	shutdown(false)

	var executable_path := _path_edit.text.strip_edges()
	if executable_path.is_empty():
		executable_path = _find_codex_executable()
		_path_edit.text = executable_path

	if executable_path.is_empty() or not FileAccess.file_exists(executable_path):
		_set_state(ConnectionState.ERROR, "Codex not found")
		_append_error(
			"The Codex executable could not be found.\n"
			+ "Set CODEX_PATH or verify that the local Codex installation is still valid."
		)
		if auto_reconnect:
			_schedule_auto_reconnect()
		return

	_save_settings()
	_set_state(ConnectionState.STARTING, "Starting Codex…")
	_append_activity("Starting the local Codex App Server")

	var arguments := PackedStringArray(["app-server", "--listen", "stdio://"])
	var process_result: Dictionary = OS.execute_with_pipe(
		executable_path,
		arguments,
		false
	)
	if process_result.is_empty():
		var fallback_path := _find_codex_executable(executable_path)
		if not fallback_path.is_empty():
			_append_activity("The preferred path is not executable; trying a local Codex fallback")
			executable_path = fallback_path
			_path_edit.text = executable_path
			_save_settings()
			process_result = OS.execute_with_pipe(
				executable_path,
				arguments,
				false
			)
	if process_result.is_empty():
		_set_state(ConnectionState.ERROR, "Startup failed")
		_append_error(
			"Could not start the Codex App Server: %s\n"
			% executable_path
			+ "Run `codex app-server --listen stdio://` in a terminal to check the installation."
		)
		if auto_reconnect:
			_schedule_auto_reconnect()
		return

	_stdio = process_result.get("stdio") as FileAccess
	_stderr = process_result.get("stderr") as FileAccess
	_process_id = int(process_result.get("pid", -1))
	_stdout_bytes.clear()
	_stdout_scan_offset = 0
	_stderr_text = ""
	_requests.clear()
	_next_request_id = 1
	_thread_id = ""
	_turn_id = ""
	_assistant_received_text = false
	_assistant_stream_text = ""
	_pending_resume_thread_id = ""
	_pending_delete_thread_id = ""
	_pending_delete_thread_title = ""
	_pending_rename_thread_id = ""
	_pending_rename_title = ""
	_pending_archive_thread_id = ""
	_pending_unarchive_thread_id = ""
	_resume_after_thread_list_id = thread_to_restore
	_thread_list_request_pending = false
	_thread_list_reload_queued = false
	_thread_list_cache.clear()
	_model_list_request_pending = false
	_waiting_for_initial_model_list = false
	_model_list_loaded = false
	_model_list_items.clear()
	_model_catalog.clear()
	_codex_default_model_id = ""
	_refresh_history_after_turn = false
	_current_turn_diff = ""
	_server_request_queue.clear()
	_active_server_request.clear()
	_question_fields.clear()
	_skills.clear()
	_rate_limits_request_pending = false
	_rate_limit_snapshot.clear()
	_rate_limit_error = ""
	_update_diff_button()
	_set_thread_selector_placeholder("Loading conversations…")
	_set_model_selector_placeholder("Syncing models…")
	_set_effort_selector_placeholder("Syncing reasoning effort…")
	_set_skills_placeholder("Syncing Skills…")
	_update_rate_limit_display()

	if _stdio == null or _process_id < 0:
		shutdown(false)
		_set_state(ConnectionState.ERROR, "Pipe connection failed")
		_append_error("Codex started, but a bidirectional communication pipe could not be created.")
		if auto_reconnect:
			_schedule_auto_reconnect()
		return

	_send_request(
		"initialize",
		{
			"clientInfo": {
				"name": CLIENT_NAME,
				"title": "Godex",
				"version": CLIENT_VERSION,
			},
			"capabilities": {
				"experimentalApi": true,
			},
		}
	)


func shutdown(update_status := true) -> void:
	var process_to_stop := _process_id

	if _stdio != null:
		_stdio.close()
	if _stderr != null:
		_stderr.close()

	_stdio = null
	_stderr = null
	_process_id = -1
	_requests.clear()
	_stdout_bytes.clear()
	_stdout_scan_offset = 0
	_server_request_queue.clear()
	_active_server_request.clear()
	if is_instance_valid(_request_auto_timer):
		_request_auto_timer.stop()
	if is_instance_valid(_approval_dialog):
		_approval_dialog.hide()
	if is_instance_valid(_question_dialog):
		_question_dialog.hide()

	if process_to_stop > 0 and OS.is_process_running(process_to_stop):
		OS.kill(process_to_stop)

	if update_status and is_instance_valid(_status_label):
		_auto_reconnect_pending = false
		_auto_reconnect_attempt = 0
		_reconnect_restore_thread_id = ""
		_set_state(ConnectionState.DISCONNECTED, "Disconnected")


func _schedule_auto_reconnect() -> void:
	if _process_id >= 0 or _auto_reconnect_pending:
		return
	if not _auto_reconnect_enabled:
		_set_state(ConnectionState.ERROR, "Automatic reconnect disabled")
		return
	if _auto_reconnect_attempt >= _auto_reconnect_max_attempts:
		_set_state(ConnectionState.ERROR, "Automatic reconnect stopped")
		_append_error(
			"The automatic reconnect limit was reached (%d attempts).\n"
			% _auto_reconnect_max_attempts
			+ "Reconnect manually or adjust the settings from the Tools menu."
		)
		return
	var delay_index := mini(
		_auto_reconnect_attempt,
		AUTO_RECONNECT_DELAYS_MS.size() - 1
	)
	var delay_msec := int(AUTO_RECONNECT_DELAYS_MS[delay_index])
	_auto_reconnect_attempt += 1
	_auto_reconnect_at_msec = Time.get_ticks_msec() + delay_msec
	_auto_reconnect_pending = true
	var delay_seconds := maxf(float(delay_msec) / 1000.0, 1.0)
	_set_state(ConnectionState.ERROR, "Reconnect in %.0f seconds" % delay_seconds)
	_append_activity(
		"Reconnect attempt %d will start in %.0f seconds"
		% [_auto_reconnect_attempt, delay_seconds]
	)


func _summarize_diagnostic(diagnostic: String) -> String:
	var cleaned := diagnostic.strip_edges()
	if cleaned.is_empty():
		return "The Codex App Server exited unexpectedly."
	if cleaned.length() > 2000:
		cleaned = "…" + cleaned.right(2000)
	return cleaned


func _record_connection_event(text: String) -> void:
	var timestamp := Time.get_time_string_from_system()
	_connection_events.append("[%s] %s" % [timestamp, text])
	while _connection_events.size() > 80:
		_connection_events.remove_at(0)


func focus_input() -> void:
	if is_instance_valid(_input):
		_input.grab_focus()


func _process(_delta: float) -> void:
	var now_msec := Time.get_ticks_msec()
	if now_msec >= _next_run_scene_status_refresh_msec:
		_next_run_scene_status_refresh_msec = (
			now_msec + RUN_SCENE_STATUS_REFRESH_MS
		)
		_update_run_scene_button()
	if (
		is_instance_valid(_settings_dialog)
		and _settings_dialog.visible
		and now_msec >= _next_settings_status_refresh_msec
	):
		_next_settings_status_refresh_msec = now_msec + 500
		var diagnostic_text := _settings_diagnostic_text()
		if _settings_status_view.text != diagnostic_text:
			_settings_status_view.text = diagnostic_text
	if _transcript_render_pending:
		_render_transcript()
	if (
		_auto_reconnect_pending
		and Time.get_ticks_msec() >= _auto_reconnect_at_msec
	):
		_auto_reconnect_pending = false
		_connect_server(true)
		return
	if _process_id < 0:
		return

	_drain_stdout()
	_drain_stderr()

	if not OS.is_process_running(_process_id):
		_drain_stdout()
		_drain_stderr()
		var diagnostic := _stderr_text.strip_edges()
		if not _thread_id.is_empty():
			_reconnect_restore_thread_id = _thread_id
		shutdown(false)
		_set_state(ConnectionState.ERROR, "Codex exited")
		if diagnostic.is_empty():
			diagnostic = "The Codex App Server exited unexpectedly."
		_append_error(
			"%s\nThe plugin will reconnect automatically and restore the current conversation."
			% _summarize_diagnostic(diagnostic)
		)
		_schedule_auto_reconnect()


func _drain_stdout() -> void:
	if _stdio == null or not _stdio.is_open():
		return

	var remaining_budget := STDOUT_READ_BUDGET_BYTES
	var available := int(_stdio.get_length())
	while available > 0 and remaining_budget > 0:
		var read_size := mini(available, remaining_budget)
		var chunk := _stdio.get_buffer(read_size)
		if chunk.is_empty():
			break
		_stdout_bytes.append_array(chunk)
		remaining_budget -= chunk.size()
		available = int(_stdio.get_length())
	_consume_stdout_lines()


func _consume_stdout_lines() -> void:
	var started_at_msec := Time.get_ticks_msec()
	while true:
		var newline_index := -1
		while _stdout_scan_offset < _stdout_bytes.size():
			if _stdout_bytes[_stdout_scan_offset] == 10:
				newline_index = _stdout_scan_offset
				break
			_stdout_scan_offset += 1

		if newline_index < 0:
			return

		var line_bytes := _stdout_bytes.slice(0, newline_index)
		_stdout_bytes = _stdout_bytes.slice(newline_index + 1)
		_stdout_scan_offset = 0
		if not line_bytes.is_empty() and line_bytes[line_bytes.size() - 1] == 13:
			line_bytes.resize(line_bytes.size() - 1)
		var line := line_bytes.get_string_from_utf8()
		if not line.is_empty():
			_handle_json_line(line)
		if Time.get_ticks_msec() - started_at_msec >= STDOUT_PROCESS_BUDGET_MS:
			return


func _drain_stderr() -> void:
	if _stderr == null or not _stderr.is_open():
		return

	var available := int(_stderr.get_length())
	while available > 0:
		var chunk := _stderr.get_buffer(available)
		if chunk.is_empty():
			break
		_stderr_text += chunk.get_string_from_utf8()
		if _stderr_text.length() > 12000:
			_stderr_text = _stderr_text.right(12000)
		available = int(_stderr.get_length())


func _handle_json_line(line: String) -> void:
	var parser := JSON.new()
	var error := parser.parse(line)
	if error != OK:
		_append_error(
			"The Codex protocol message is not valid JSON.\n"
			+ "Location: line %d; %s\n"
			% [parser.get_error_line(), parser.get_error_message()]
			+ "This usually means the Codex App Server version is incompatible with the plugin; "
			+ "update Codex, then reconnect from the Tools menu."
		)
		return

	var message: Variant = parser.data
	if typeof(message) != TYPE_DICTIONARY:
		return

	_handle_rpc_message(message as Dictionary)


func _handle_rpc_message(message: Dictionary) -> void:
	if message.has("id") and message.has("method"):
		_handle_server_request(message)
		return

	if message.has("id"):
		_handle_response(message)
		return

	if message.has("method"):
		_handle_notification(str(message.get("method", "")), message.get("params", {}))


func _handle_response(message: Dictionary) -> void:
	var request_id := int(message.get("id", -1))
	var request_method := str(_requests.get(request_id, ""))
	_requests.erase(request_id)

	if message.has("error"):
		var error_value: Variant = message.get("error")
		var error_message := _describe_rpc_error(request_method, error_value)
		_handle_request_error(request_method, error_message)
		return

	var result: Dictionary = message.get("result", {}) as Dictionary
	match request_method:
		"initialize":
			_send_notification("initialized", {})
			_request_rate_limits()
			_load_skills(true)
			_load_model_list(true)
		"model/list":
			_handle_model_list_response(result)
		"account/rateLimits/read":
			_rate_limits_request_pending = false
			_rate_limit_snapshot = result
			_rate_limit_error = (
				"The current Codex login did not return an account usage snapshot."
				if result.is_empty()
				else ""
			)
			_update_rate_limit_display()
		"skills/list":
			_apply_skills_response(result)
		"mcpServerStatus/list":
			_show_mcp_status_response(result)
		"thread/list":
			_handle_thread_list_response(result)
		"thread/start":
			var thread: Dictionary = result.get("thread", {}) as Dictionary
			_thread_id = str(thread.get("id", ""))
			if _thread_id.is_empty():
				_set_state(ConnectionState.ERROR, "Could not create conversation")
				_append_error("Codex did not return a conversation ID.")
				return
			_adopt_new_thread_composer_state(_thread_id)
			_ensure_thread_option(thread)
			_select_thread_by_id(_thread_id)
			_set_state(ConnectionState.READY, "Connected")
			_append_activity("New conversation created and project context loaded")
			_flush_pending_prompt()
			_flush_followup_queue()
		"thread/resume":
			var resumed_thread: Dictionary = result.get("thread", {}) as Dictionary
			_thread_id = str(resumed_thread.get("id", _pending_resume_thread_id))
			_pending_resume_thread_id = ""
			if _thread_id.is_empty():
				_set_state(ConnectionState.ERROR, "Could not resume conversation")
				_append_error("Codex did not return a conversation to resume.")
				return
			_ensure_thread_option(resumed_thread)
			_select_thread_by_id(_thread_id)
			var resumed_turns: Variant = resumed_thread.get("turns")
			if typeof(resumed_turns) == TYPE_ARRAY:
				_render_thread_history(resumed_thread)
				_set_state(ConnectionState.READY, "Conversation resumed")
				_flush_pending_prompt()
				_flush_followup_queue()
			else:
				_send_request(
					"thread/read",
					{"threadId": _thread_id, "includeTurns": true}
				)
		"thread/read":
			var history_thread: Dictionary = result.get("thread", {}) as Dictionary
			_thread_id = str(history_thread.get("id", _thread_id))
			var refreshed_after_turn := _refresh_history_after_turn
			_render_thread_history(history_thread, refreshed_after_turn)
			_ensure_thread_option(history_thread)
			_select_thread_by_id(_thread_id)
			_refresh_history_after_turn = false
			if refreshed_after_turn:
				_set_state(ConnectionState.READY, "Completed")
				_load_thread_list()
			elif _show_archived_threads:
				_set_state(ConnectionState.READY, "Previewing archived conversation")
			else:
				_set_state(ConnectionState.READY, "Conversation resumed")
				_flush_pending_prompt()
				_flush_followup_queue()
		"thread/name/set":
			_update_thread_option_title(_pending_rename_thread_id, _pending_rename_title)
			_pending_rename_thread_id = ""
			_pending_rename_title = ""
			_set_state(ConnectionState.READY, "Conversation renamed")
		"thread/fork":
			var forked_thread: Dictionary = result.get("thread", {}) as Dictionary
			var forked_thread_id := str(forked_thread.get("id", ""))
			if forked_thread_id.is_empty():
				_set_state(ConnectionState.READY, "Could not create fork")
				_append_error("Codex did not return a forked conversation ID.")
				return
			_show_archived_threads = false
			_switch_composer_state(forked_thread_id)
			_thread_id = forked_thread_id
			_ensure_thread_option(forked_thread)
			_select_thread_by_id(forked_thread_id)
			_set_state(ConnectionState.STARTING_THREAD, "Opening conversation fork…")
			_send_request(
				"thread/read",
				{"threadId": forked_thread_id, "includeTurns": true}
			)
		"thread/archive":
			var archived_thread_id := _pending_archive_thread_id
			_pending_archive_thread_id = ""
			if archived_thread_id == _thread_id:
				_switch_composer_state("")
				_thread_id = ""
				_turn_id = ""
				_clear_transcript()
				_append_system_message("The conversation was archived and can be restored from the archive.")
			_remove_thread_option(archived_thread_id)
			_load_thread_list()
		"thread/unarchive":
			var restored_thread: Dictionary = result.get("thread", {}) as Dictionary
			var restored_thread_id := str(
				restored_thread.get("id", _pending_unarchive_thread_id)
			)
			_pending_unarchive_thread_id = ""
			_show_archived_threads = false
			_switch_composer_state("")
			_thread_id = ""
			_clear_transcript()
			_append_system_message("Conversation restored; reopening it…")
			_resume_after_thread_list_id = restored_thread_id
			_load_thread_list()
		"thread/delete":
			_handle_thread_delete_response()
		"turn/start":
			var turn: Dictionary = result.get("turn", {}) as Dictionary
			_turn_id = str(turn.get("id", _turn_id))
			_set_state(ConnectionState.TURN_RUNNING, "Godex is working…")
		"turn/steer":
			_set_state(ConnectionState.TURN_RUNNING, "Message appended")
		"turn/interrupt":
			_append_activity("Requested to stop the current turn")
		"review/start":
			var review_turn: Dictionary = result.get("turn", {}) as Dictionary
			_turn_id = str(review_turn.get("id", _turn_id))
			_set_state(ConnectionState.TURN_RUNNING, "Godex is reviewing changes…")
		"thread/compact/start":
			_append_activity("Context compaction started")


func _handle_request_error(request_method: String, error_message: String) -> void:
	_append_error(
		"%s failed\n%s"
		% [_request_display_name(request_method), error_message]
	)

	match request_method:
		"initialize":
			_set_state(ConnectionState.ERROR, "Incompatible Codex protocol")
		"model/list":
			_model_list_request_pending = false
			if _model_list_items.is_empty():
				if not _model_list_loaded:
					_set_model_selector_fallback()
			else:
				_apply_model_list(_model_list_items)
			_model_list_items.clear()
			_finish_model_sync(false)
		"thread/list":
			_thread_list_request_pending = false
			if _thread_list_reload_queued:
				_thread_list_reload_queued = false
				_load_thread_list()
				return
			if _thread_id.is_empty():
				if _show_archived_threads:
					_set_state(ConnectionState.READY, "Could not load archive")
				else:
					_start_thread()
			else:
				_set_state(ConnectionState.READY, "Connected")
				_flush_pending_prompt()
				_flush_followup_queue()
		"thread/read":
			if _refresh_history_after_turn:
				_refresh_history_after_turn = false
				_set_state(ConnectionState.READY, "Completed (history formatting failed)")
				_load_thread_list()
				return
			var failed_read_thread_id := _thread_id
			_thread_id = ""
			_remove_thread_option(failed_read_thread_id)
			_load_thread_list()
		"thread/resume":
			var failed_thread_id := _pending_resume_thread_id
			if failed_thread_id.is_empty():
				failed_thread_id = _thread_id
			_pending_resume_thread_id = ""
			_thread_id = ""
			_remove_thread_option(failed_thread_id)
			if "already has an active writer" in error_message.to_lower():
				_create_new_after_connect = true
				_append_activity(
					"This conversation is open in another Codex client. "
					+ "Creating a separate Godex conversation."
				)
			_load_thread_list()
		"thread/delete":
			_pending_delete_thread_id = ""
			_pending_delete_thread_title = ""
			_set_state(ConnectionState.READY, "Delete failed")
		"thread/name/set":
			_pending_rename_thread_id = ""
			_pending_rename_title = ""
			_set_state(ConnectionState.READY, "Rename failed")
		"thread/fork":
			_set_state(ConnectionState.READY, "Could not create fork")
		"thread/archive":
			_pending_archive_thread_id = ""
			_set_state(ConnectionState.READY, "Archive failed")
		"thread/unarchive":
			var fallback_unarchive_thread_id := _pending_unarchive_thread_id
			_pending_unarchive_thread_id = ""
			if fallback_unarchive_thread_id.is_empty():
				_resume_after_thread_list_id = ""
				_set_state(ConnectionState.READY, "Could not restore archive")
			else:
				_show_archived_threads = false
				_thread_id = ""
				_resume_after_thread_list_id = fallback_unarchive_thread_id
				_set_state(ConnectionState.STARTING_THREAD, "Reloading restored conversation…")
				_load_thread_list()
		"account/rateLimits/read":
			_rate_limits_request_pending = false
			_rate_limit_error = error_message
			_update_rate_limit_display()
		"skills/list":
			_set_skills_placeholder("Could not sync Skills")
		"mcpServerStatus/list":
			_show_inventory("MCP status", "Could not read MCP status:\n%s" % error_message)
		"review/start":
			_turn_id = ""
			_set_state(ConnectionState.READY, "Could not start code review")
		"thread/compact/start":
			_turn_id = ""
			_set_state(ConnectionState.READY, "Could not start context compaction")
		_:
			_set_state(ConnectionState.ERROR, "Request failed")


func _handle_notification(method: String, params_value: Variant) -> void:
	var params: Dictionary = params_value as Dictionary
	match method:
		"turn/started":
			var turn: Dictionary = params.get("turn", {}) as Dictionary
			_turn_id = str(turn.get("id", _turn_id))
			_set_state(ConnectionState.TURN_RUNNING, "Godex is working…")
		"item/agentMessage/delta":
			var delta := str(params.get("delta", ""))
			if not delta.is_empty():
				if not _assistant_received_text:
					_assistant_stream_text = ""
				_assistant_stream_text += delta
				_assistant_received_text = true
				_request_transcript_render()
		"item/plan/delta":
			var plan_delta := str(params.get("delta", ""))
			if not plan_delta.is_empty():
				_plan_stream_text += plan_delta
				_set_plan_text(_plan_stream_text)
		"item/started":
			_handle_item_started(params.get("item", {}))
		"item/completed":
			_handle_item_completed(params.get("item", {}))
		"turn/diff/updated":
			_handle_turn_diff_updated(params)
		"turn/plan/updated":
			_handle_plan_updated(params)
		"error":
			var error_data: Dictionary = params.get("error", {}) as Dictionary
			var error_message := str(error_data.get("message", "Codex returned an error"))
			if bool(params.get("willRetry", false)):
				_append_activity(error_message)
			else:
				_append_error(error_message)
				_set_state(ConnectionState.READY, "Connected")
		"turn/completed":
			_finish_turn(params)
		"thread/name/updated":
			var thread_name_value: Variant = params.get("threadName")
			var thread_name := ""
			if thread_name_value != null:
				thread_name = str(thread_name_value)
			_update_thread_option_title(
				str(params.get("threadId", "")),
				thread_name
			)
		"thread/deleted":
			_handle_thread_deleted_notification(str(params.get("threadId", "")))
		"thread/archived":
			_handle_thread_archived_notification(str(params.get("threadId", "")))
		"thread/unarchived":
			if _show_archived_threads:
				_remove_thread_option(str(params.get("threadId", "")))
		"account/rateLimits/updated":
			_request_rate_limits()
		"skills/changed":
			_load_skills(true)
		"serverRequest/resolved":
			_handle_server_request_resolved(params.get("requestId"))


func _handle_item_started(item_value: Variant) -> void:
	if typeof(item_value) != TYPE_DICTIONARY:
		return
	var item: Dictionary = item_value as Dictionary
	match str(item.get("type", "")):
		"commandExecution", "fileChange", "mcpToolCall", "dynamicToolCall", "webSearch":
			_upsert_tool_card(item, "running")
		"plan":
			_plan_stream_text = ""
			_plan_entries.clear()
			_plan_explanation = ""
			_plan_text = ""
			_render_plan_panel()
		"enteredReviewMode":
			_append_activity("Code review started")
		"contextCompaction":
			_append_activity("Compacting earlier conversation context")
		_:
			if _is_generated_image_item(item):
				_upsert_tool_card(item, "running")


func _handle_item_completed(item_value: Variant) -> void:
	if typeof(item_value) != TYPE_DICTIONARY:
		return
	var item: Dictionary = item_value as Dictionary
	var item_type := str(item.get("type", ""))

	if item_type == "agentMessage":
		var text := str(item.get("text", ""))
		if not text.is_empty():
			_assistant_stream_text = text
			_assistant_received_text = true
			_request_transcript_render(true)
	elif item_type == "plan":
		_plan_stream_text = str(item.get("text", ""))
		_set_plan_text(_plan_stream_text)
	elif item_type in [
		"commandExecution",
		"fileChange",
		"mcpToolCall",
		"dynamicToolCall",
		"webSearch",
	]:
		_upsert_tool_card(item, "completed")
	elif item_type == "exitedReviewMode":
		_append_activity("Code review completed")
	elif item_type == "contextCompaction":
		_append_activity("Conversation context compacted")
	elif _is_generated_image_item(item):
		_upsert_tool_card(item, "completed")


func _handle_plan_updated(params: Dictionary) -> void:
	var entries: Array[Dictionary] = []
	var plan_value: Variant = params.get("plan", [])
	if typeof(plan_value) == TYPE_ARRAY:
		for step_value in plan_value as Array:
			if typeof(step_value) != TYPE_DICTIONARY:
				continue
			var step: Dictionary = step_value as Dictionary
			var step_text := str(step.get("step", "")).strip_edges()
			if step_text.is_empty():
				continue
			entries.append(
				{
					"step": step_text,
					"status": _normalize_plan_status(
						str(step.get("status", "pending"))
					),
				}
			)
	_plan_entries = entries
	_plan_explanation = str(params.get("explanation", "")).strip_edges()
	_plan_text = ""
	_render_plan_panel()


func _normalize_plan_status(status: String) -> String:
	match status.to_lower().replace("_", ""):
		"inprogress", "running":
			return "inProgress"
		"completed", "complete", "done":
			return "completed"
		_:
			return "pending"


func _set_plan_text(text: String) -> void:
	_plan_text = text.strip_edges()
	_plan_entries.clear()
	_plan_explanation = ""
	var explanation_lines := PackedStringArray()
	for raw_line in _plan_text.split("\n", true):
		var line := str(raw_line).strip_edges()
		if line.is_empty():
			continue
		var parsed := _parse_plan_line(line)
		if parsed.is_empty():
			if _plan_entries.is_empty():
				explanation_lines.append(line)
			continue
		_plan_entries.append(parsed)
	if not explanation_lines.is_empty():
		_plan_explanation = "\n".join(explanation_lines)
	elif _plan_entries.is_empty():
		_plan_explanation = _plan_text
	_render_plan_panel()


func _parse_plan_line(line: String) -> Dictionary:
	var step_text := line
	var status := "pending"
	var is_step := false
	for checkbox_prefix in ["- [x] ", "- [X] ", "* [x] ", "* [X] "]:
		if step_text.begins_with(checkbox_prefix):
			step_text = step_text.substr(checkbox_prefix.length())
			status = "completed"
			is_step = true
			break
	if not is_step:
		for checkbox_prefix in ["- [ ] ", "* [ ] "]:
			if step_text.begins_with(checkbox_prefix):
				step_text = step_text.substr(checkbox_prefix.length())
				is_step = true
				break
	if not is_step and (
		step_text.begins_with("- ")
		or step_text.begins_with("* ")
		or step_text.begins_with("• ")
	):
		step_text = step_text.substr(2)
		is_step = true
	if not is_step:
		var separator_index := step_text.find(". ")
		if separator_index > 0:
			var prefix := step_text.left(separator_index)
			if prefix.is_valid_int():
				step_text = step_text.substr(separator_index + 2)
				is_step = true
	if not is_step:
		return {}
	return {"step": step_text.strip_edges(), "status": status}


func _toggle_plan_panel() -> void:
	_plan_expanded = not _plan_expanded
	_render_plan_panel()


func _render_plan_panel() -> void:
	if not is_instance_valid(_plan_panel):
		return
	var has_plan := not _plan_entries.is_empty() or not _plan_explanation.is_empty()
	_plan_panel.visible = has_plan
	if not has_plan:
		return

	var completed := 0
	var in_progress := 0
	for entry in _plan_entries:
		match str(entry.get("status", "pending")):
			"completed":
				completed += 1
			"inProgress":
				in_progress += 1
	var title := ("▾" if _plan_expanded else "▸") + " Plan"
	if not _plan_entries.is_empty():
		title += " · %d/%d" % [completed, _plan_entries.size()]
		if in_progress > 0:
			title += " · In progress"
	else:
		title += " · Proposed"
	_plan_header.text = title
	_plan_header.tooltip_text = (
		_plan_text
		if not _plan_text.is_empty()
		else "Expand or collapse the current Godex task plan"
	)
	_plan_body.visible = _plan_expanded
	if not _plan_expanded:
		return

	_plan_explanation_label.text = _plan_explanation
	_plan_explanation_label.visible = not _plan_explanation.is_empty()
	for child in _plan_steps.get_children():
		_plan_steps.remove_child(child)
		child.queue_free()
	for entry in _plan_entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 7)
		_plan_steps.add_child(row)

		var status := str(entry.get("status", "pending"))
		var status_label := Label.new()
		status_label.custom_minimum_size = Vector2(16.0, 0.0)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		match status:
			"completed":
				status_label.text = "✓"
				status_label.add_theme_color_override(
					"font_color",
					Color(0.34, 0.79, 0.51)
				)
			"inProgress":
				status_label.text = "●"
				status_label.add_theme_color_override(
					"font_color",
					Color(0.35, 0.65, 1.0)
				)
			_:
				status_label.text = "○"
				status_label.add_theme_color_override(
					"font_color",
					Color(0.55, 0.59, 0.66)
				)
		row.add_child(status_label)

		var step_label := Label.new()
		step_label.text = str(entry.get("step", ""))
		step_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		step_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		step_label.add_theme_font_size_override("font_size", 12)
		step_label.add_theme_color_override(
			"font_color",
			Color(0.72, 0.75, 0.81)
			if status == "completed"
			else Color(0.91, 0.93, 0.97)
		)
		row.add_child(step_label)


func _tool_item_key(item: Dictionary) -> String:
	for key in ["id", "callId", "itemId"]:
		var value := str(item.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	var item_type := str(item.get("type", "tool"))
	var identity := str(
		item.get(
			"command",
			item.get("tool", item.get("query", item.get("server", "")))
		)
	)
	return "%s:%s" % [item_type, identity]


func _single_line_preview(text: String, limit := 120) -> String:
	var preview := text.replace("\r", " ").replace("\n", " ").strip_edges()
	while "  " in preview:
		preview = preview.replace("  ", " ")
	if preview.length() > limit:
		return preview.left(limit - 1) + "…"
	return preview


func _json_detail(value: Variant) -> String:
	if value == null:
		return ""
	var sanitized: Variant = _sanitize_image_payload(value)
	if typeof(sanitized) in [TYPE_DICTIONARY, TYPE_ARRAY]:
		return JSON.stringify(sanitized, "  ")
	return str(sanitized)


func _sanitize_image_payload(value: Variant, depth := 0) -> Variant:
	if depth > 8:
		return "…"
	match typeof(value):
		TYPE_DICTIONARY:
			var cleaned := {}
			for key_value in (value as Dictionary).keys():
				var key := str(key_value)
				cleaned[key] = _sanitize_image_payload(
					(value as Dictionary).get(key_value),
					depth + 1
				)
			return cleaned
		TYPE_ARRAY:
			var cleaned_array := []
			for child in value as Array:
				cleaned_array.append(
					_sanitize_image_payload(child, depth + 1)
				)
			return cleaned_array
		TYPE_STRING:
			var text := str(value)
			if text.begins_with("data:image/"):
				return _image_data_placeholder(text.length())
			if not _base64_image_mime(text).is_empty():
				return _image_data_placeholder(text.length())
			if text.length() > 12000:
				return text.left(12000) + "\n… (output truncated)"
	return value


func _image_data_placeholder(encoded_length: int) -> String:
	return "[image data · %d KB]" % maxi(
		int(float(encoded_length) * 0.75 / 1024.0),
		1
	)


func _base64_image_mime(encoded: String) -> String:
	if (
		encoded.length() < 128
		or encoded.length() % 4 != 0
		or encoded.begins_with("data:")
	):
		return ""
	var sample_length := mini(encoded.length(), 64)
	sample_length -= sample_length % 4
	if sample_length < 4:
		return ""
	for index in range(sample_length):
		var character := encoded.unicode_at(index)
		var is_base64_character := (
			(character >= 0x41 and character <= 0x5a)
			or (character >= 0x61 and character <= 0x7a)
			or (character >= 0x30 and character <= 0x39)
			or character == 0x2b
			or character == 0x2f
			or character == 0x3d
		)
		if not is_base64_character:
			return ""
	var sample := Marshalls.base64_to_raw(encoded.left(sample_length))
	if sample.size() >= 8 and (
		sample[0] == 0x89
		and sample[1] == 0x50
		and sample[2] == 0x4e
		and sample[3] == 0x47
		and sample[4] == 0x0d
		and sample[5] == 0x0a
		and sample[6] == 0x1a
		and sample[7] == 0x0a
	):
		return "image/png"
	if (
		sample.size() >= 3
		and sample[0] == 0xff
		and sample[1] == 0xd8
		and sample[2] == 0xff
	):
		return "image/jpeg"
	if sample.size() >= 12 and (
		sample[0] == 0x52
		and sample[1] == 0x49
		and sample[2] == 0x46
		and sample[3] == 0x46
		and sample[8] == 0x57
		and sample[9] == 0x45
		and sample[10] == 0x42
		and sample[11] == 0x50
	):
		return "image/webp"
	return ""


func _raw_base64_image_source(value: Variant) -> String:
	if typeof(value) != TYPE_STRING:
		return ""
	var encoded := str(value)
	if encoded.begins_with("data:image/"):
		return encoded
	var mime_type := _base64_image_mime(encoded)
	if mime_type.is_empty():
		return ""
	return "data:%s;base64," % mime_type + encoded


func _image_extension_from_source(source: String) -> String:
	var cleaned := source
	if not cleaned.begins_with("data:image/"):
		if cleaned.length() > IMAGE_SOURCE_TEXT_SCAN_LIMIT:
			return ""
		cleaned = cleaned.strip_edges()
	if cleaned.begins_with("data:image/"):
		var mime_end := cleaned.find(";")
		if mime_end < 0:
			mime_end = cleaned.find(",")
		var mime_extension := cleaned.substr(11, mime_end - 11).to_lower()
		if mime_extension == "jpeg":
			return "jpg"
		if mime_extension == "svg+xml":
			return "svg"
		return mime_extension
	var suffix_start := cleaned.find("?")
	if suffix_start >= 0:
		cleaned = cleaned.left(suffix_start)
	suffix_start = cleaned.find("#")
	if suffix_start >= 0:
		cleaned = cleaned.left(suffix_start)
	return cleaned.get_extension().to_lower()


func _looks_like_image_source(source: String) -> bool:
	if source.begins_with("data:image/"):
		return true
	if source.length() > IMAGE_SOURCE_TEXT_SCAN_LIMIT:
		return false
	var cleaned := source.strip_edges()
	if cleaned.begins_with("<") and cleaned.ends_with(">"):
		cleaned = cleaned.substr(1, cleaned.length() - 2)
	if cleaned.begins_with("data:image/"):
		return true
	return _image_extension_from_source(cleaned) in IMAGE_EXTENSIONS and (
		cleaned.begins_with("res://")
		or cleaned.begins_with("file://")
		or cleaned.begins_with("http://")
		or cleaned.begins_with("https://")
		or cleaned.is_absolute_path()
	)


func _normalize_image_source(source: String) -> String:
	if source.begins_with("data:image/"):
		return source
	if source.length() > IMAGE_SOURCE_TEXT_SCAN_LIMIT:
		return ""
	var cleaned := source.strip_edges()
	if cleaned.begins_with("<") and cleaned.ends_with(">"):
		cleaned = cleaned.substr(1, cleaned.length() - 2)
	if cleaned.begins_with("file://"):
		cleaned = cleaned.trim_prefix("file://")
	if not cleaned.begins_with("data:image/"):
		cleaned = cleaned.uri_decode()
	return cleaned


func _append_unique_image_source(sources: Array, source: String) -> void:
	var normalized := _normalize_image_source(source)
	if not _looks_like_image_source(normalized):
		return
	if not normalized in sources:
		sources.append(normalized)


func _collect_image_sources(
	value: Variant,
	sources: Array,
	depth := 0
) -> void:
	if depth > 8 or value == null:
		return
	match typeof(value):
		TYPE_DICTIONARY:
			var data: Dictionary = value as Dictionary
			for child in data.values():
				_collect_image_sources(child, sources, depth + 1)
		TYPE_ARRAY:
			for child in value as Array:
				_collect_image_sources(child, sources, depth + 1)
		TYPE_STRING:
			var raw_text := str(value)
			if (
				raw_text.length() > IMAGE_SOURCE_TEXT_SCAN_LIMIT
				and not raw_text.begins_with("data:image/")
			):
				return
			var text := raw_text.strip_edges()
			if _looks_like_image_source(text):
				_append_unique_image_source(sources, text)
				return
			if (
				(text.begins_with("{") and text.ends_with("}"))
				or (text.begins_with("[") and text.ends_with("]"))
			):
				var parsed: Variant = JSON.parse_string(text)
				if parsed != null:
					_collect_image_sources(parsed, sources, depth + 1)
			if _image_path_regex_ready:
				for result in _image_path_regex.search_all(text):
					_append_unique_image_source(
						sources,
						result.get_string()
					)


func _tool_image_sources(item: Dictionary) -> Array:
	var sources := []
	if not _is_generated_image_item(item):
		return sources
	for saved_path_key in ["savedPath", "saved_path"]:
		var saved_path := str(item.get(saved_path_key, ""))
		if not _looks_like_image_source(saved_path):
			continue
		var normalized_saved_path := _normalize_image_source(saved_path)
		var local_path := _image_local_path(normalized_saved_path)
		if not local_path.is_empty() and FileAccess.file_exists(local_path):
			sources.append(normalized_saved_path)
			return sources
	var raw_result_source := _raw_base64_image_source(item.get("result"))
	if not raw_result_source.is_empty():
		sources.append(raw_result_source)
		return sources
	for key in [
		"contentItems",
		"result",
		"output",
		"output_hint",
		"image_url",
		"imageUrl",
		"image_path",
		"imagePath",
		"path",
		"savedPath",
		"saved_path",
	]:
		if item.has(key):
			_collect_image_sources(item.get(key), sources)
	return sources


func _is_image_tool(item: Dictionary) -> bool:
	var identity := (
		str(item.get("tool", ""))
		+ " "
		+ str(item.get("server", ""))
	).to_lower()
	return (
		"imagegen" in identity
		or "image_gen" in identity
		or "generate_image" in identity
		or "generateimage" in identity
		or "image generation" in identity
		or "image_generation" in identity
		or "gpt-image" in identity
	)


func _is_generated_image_item(item: Dictionary) -> bool:
	if _is_image_tool(item):
		return true
	var item_type := str(item.get("type", "")).to_lower()
	var compact_type := (
		item_type.replace("_", "").replace("-", "").replace(" ", "")
	)
	return compact_type in [
		"generatedimage",
		"imagegeneration",
		"imagegenerationresult",
		"outputimage",
	]


func _tool_card_content(item: Dictionary, lifecycle: String) -> Dictionary:
	var item_type := str(item.get("type", "tool"))
	var title := "Tool call"
	var summary := ""
	var details := PackedStringArray()
	var image_sources := _tool_image_sources(item)
	if not image_sources.is_empty():
		title = "Image"
		summary = "Loading…" if lifecycle == "running" else "Generated"
	match item_type:
		"commandExecution":
			title = "Command"
			var command := _json_detail(item.get("command", ""))
			summary = _single_line_preview(command)
			if not command.is_empty():
				details.append(command)
			for output_key in ["aggregatedOutput", "output", "stdout", "stderr"]:
				var output := _json_detail(item.get(output_key, "")).strip_edges()
				if not output.is_empty():
					details.append("%s\n%s" % [output_key, output])
			var exit_code: Variant = item.get("exitCode")
			if exit_code != null:
				details.append("Exit code: %s" % str(exit_code))
		"fileChange":
			title = "File changes"
			var changes_value: Variant = item.get("changes", [])
			var change_count := (
				(changes_value as Array).size()
				if typeof(changes_value) == TYPE_ARRAY
				else 0
			)
			summary = "%d files" % change_count
			if change_count > 0:
				for change_value in changes_value as Array:
					if typeof(change_value) == TYPE_DICTIONARY:
						var change: Dictionary = change_value as Dictionary
						var path := str(
							change.get(
								"path",
								change.get("filePath", change.get("file", "File"))
							)
						)
						var change_kind := str(
							change.get("kind", change.get("type", "Modified"))
						)
						details.append("%s · %s" % [change_kind, path])
					else:
						details.append(str(change_value))
		"imageGeneration":
			title = "Image generation"
			summary = "Generating…" if lifecycle == "running" else "Generated"
			var revised_prompt := str(item.get("revisedPrompt", "")).strip_edges()
			if not revised_prompt.is_empty():
				details.append(
					"revisedPrompt\n" + _single_line_preview(revised_prompt, 500)
				)
			var saved_path := str(
				item.get("savedPath", item.get("saved_path", ""))
			).strip_edges()
			if not saved_path.is_empty():
				details.append("savedPath\n" + saved_path)
			var encoded_result := str(item.get("result", ""))
			if not encoded_result.is_empty():
				details.append(
					"result\n" + _image_data_placeholder(encoded_result.length())
				)
		"mcpToolCall":
			var server := str(item.get("server", "MCP"))
			var tool := str(item.get("tool", "Tool"))
			if _is_image_tool(item):
				title = "Image generation"
				summary = "Generating…" if lifecycle == "running" else "Generated"
			else:
				title = "MCP · %s" % server
				summary = tool
			for key in ["arguments", "result", "contentItems", "error"]:
				var value := _json_detail(item.get(key))
				if not value.is_empty():
					details.append("%s\n%s" % [key, value])
		"dynamicToolCall":
			if _is_image_tool(item):
				title = "Image generation"
				summary = "Generating…" if lifecycle == "running" else "Generated"
			else:
				title = "Tool"
				summary = str(item.get("tool", "Dynamic tool"))
			for key in ["arguments", "result", "contentItems", "error"]:
				var value := _json_detail(item.get(key))
				if not value.is_empty():
					details.append("%s\n%s" % [key, value])
		"webSearch":
			title = "Web search"
			summary = _single_line_preview(str(item.get("query", "")))
			var result := _json_detail(item.get("result"))
			if not result.is_empty():
				details.append(result)
	var status := lifecycle
	if item.has("status"):
		status = str(item.get("status", lifecycle))
	var exit_code_value: Variant = item.get("exitCode")
	if exit_code_value != null and int(exit_code_value) != 0:
		status = "failed"
	return {
		"title": title,
		"summary": summary,
		"details": "\n\n".join(details),
		"status": status,
		"images": image_sources,
	}


func _upsert_tool_card(item: Dictionary, lifecycle: String) -> void:
	var item_key := _tool_item_key(item)
	var entry_id := int(_tool_entry_by_item_id.get(item_key, 0))
	var content := _tool_card_content(item, lifecycle)
	if entry_id == 0:
		if lifecycle == "running" and not _assistant_stream_text.is_empty():
			_transcript_entries.append(
				{"kind": "assistant", "text": _assistant_stream_text}
			)
			_assistant_stream_text = ""
		entry_id = _next_transcript_entry_id
		_next_transcript_entry_id += 1
		var entry := {
			"kind": "tool",
			"id": entry_id,
			"expanded": false,
		}
		entry.merge(content, true)
		_transcript_entries.append(entry)
		_tool_entry_by_item_id[item_key] = entry_id
	else:
		for entry_index in range(_transcript_entries.size()):
			if int(_transcript_entries[entry_index].get("id", 0)) == entry_id:
				_transcript_entries[entry_index].merge(content, true)
				break
	_request_transcript_render(true)


func _finish_turn(params: Dictionary) -> void:
	if _assistant_received_text and not _assistant_stream_text.is_empty():
		_transcript_entries.append(
			{"kind": "assistant", "text": _assistant_stream_text}
		)
	_assistant_stream_text = ""
	_request_transcript_render(true)

	var turn: Dictionary = params.get("turn", {}) as Dictionary
	var status := str(turn.get("status", "completed"))
	if status != "completed":
		_append_error("Codex turn status: %s" % status)

	_turn_id = ""
	_assistant_received_text = false
	_update_policy_label()
	_refresh_history_after_turn = true
	_set_state(ConnectionState.STARTING_THREAD, "Finalizing response…")
	_send_request(
		"thread/read",
		{"threadId": _thread_id, "includeTurns": true}
	)


func _handle_turn_diff_updated(params: Dictionary) -> void:
	var notification_thread_id := str(params.get("threadId", ""))
	if not notification_thread_id.is_empty() and notification_thread_id != _thread_id:
		return
	_current_turn_diff = str(params.get("diff", ""))
	_diff_files = _parse_unified_diff(_current_turn_diff)
	_diff_resolution.clear()
	_update_diff_button()
	if is_instance_valid(_diff_dialog) and _diff_dialog.visible:
		_populate_diff_tree()


func _clear_current_diff() -> void:
	_current_turn_diff = ""
	_diff_files.clear()
	_diff_resolution.clear()
	_update_diff_button()


func _update_diff_button() -> void:
	if not is_instance_valid(_diff_button):
		return
	if _current_turn_diff.is_empty():
		_diff_button.disabled = true
		_diff_button.tooltip_text = "No project diff is available"
		return

	var additions := 0
	var deletions := 0
	for line in _current_turn_diff.split("\n"):
		if line.begins_with("+") and not line.begins_with("+++"):
			additions += 1
		elif line.begins_with("-") and not line.begins_with("---"):
			deletions += 1
	_diff_button.disabled = false
	_diff_button.tooltip_text = (
		"View the unified diff from the latest turn\n%d lines added, %d lines deleted"
		% [additions, deletions]
	)


func _show_current_diff() -> void:
	if _current_turn_diff.is_empty():
		return
	if _diff_files.is_empty():
		_diff_files = _parse_unified_diff(_current_turn_diff)
	_populate_diff_tree()
	if DisplayServer.get_name() != "headless":
		_diff_dialog.popup_centered(Vector2i(1040, 680))


func _clean_diff_path(raw_path: String) -> String:
	var path := raw_path.strip_edges()
	if "\t" in path:
		path = path.get_slice("\t", 0)
	if path.begins_with("\"") and path.ends_with("\""):
		path = path.substr(1, path.length() - 2)
	if path in ["/dev/null", "dev/null"]:
		return ""
	if path.begins_with("a/") or path.begins_with("b/"):
		path = path.substr(2)
	return path


func _diff_hunk_new_line(header: String) -> int:
	var plus_index := header.find("+")
	if plus_index < 0:
		return 0
	var end_index := header.find(" ", plus_index)
	var range_text := (
		header.substr(plus_index + 1)
		if end_index < 0
		else header.substr(plus_index + 1, end_index - plus_index - 1)
	)
	var line_text := range_text.get_slice(",", 0)
	return int(line_text) if line_text.is_valid_int() else 0


func _diff_hunk_summary(header: String, lines: PackedStringArray) -> String:
	var context := ""
	for line in lines:
		if line.begins_with(" ") and not line.strip_edges().is_empty():
			context = line.strip_edges()
			break
	if context.length() > 70:
		context = context.left(69) + "…"
	return header if context.is_empty() else "%s  %s" % [header, context]


func _finalize_diff_file(file: Dictionary) -> Dictionary:
	var old_path := str(file.get("old_path", ""))
	var new_path := str(file.get("new_path", ""))
	var path := new_path if not new_path.is_empty() else old_path
	var raw_lines: PackedStringArray = file.get("raw_lines", PackedStringArray())
	var raw_text := "\n".join(raw_lines)
	var status := "modified"
	if old_path.is_empty() or "new file mode" in raw_text:
		status = "added"
	elif new_path.is_empty() or "deleted file mode" in raw_text:
		status = "deleted"
	elif "rename from " in raw_text or "rename to " in raw_text:
		status = "renamed"
	file["path"] = path
	file["status"] = status
	file["patch"] = raw_text + ("\n" if not raw_text.is_empty() else "")
	var header_lines: PackedStringArray = file.get(
		"header_lines",
		PackedStringArray()
	)
	var hunks: Array = file.get("hunks", []) as Array
	for hunk_index in range(hunks.size()):
		var hunk: Dictionary = hunks[hunk_index] as Dictionary
		var hunk_lines: PackedStringArray = hunk.get(
			"lines",
			PackedStringArray()
		)
		hunk["patch"] = (
			"\n".join(header_lines)
			+ "\n"
			+ "\n".join(hunk_lines)
			+ "\n"
		)
		hunk["line"] = _diff_hunk_new_line(str(hunk.get("header", "")))
		hunk["summary"] = _diff_hunk_summary(
			str(hunk.get("header", "")),
			hunk_lines
		)
		hunks[hunk_index] = hunk
	file["hunks"] = hunks
	return file


func _parse_unified_diff(diff_text: String) -> Array[Dictionary]:
	var files: Array[Dictionary] = []
	var current: Dictionary = {}
	var current_hunk_index := -1
	for raw_line in diff_text.split("\n", true):
		var line := str(raw_line)
		if line.begins_with("diff --git "):
			if not current.is_empty():
				files.append(_finalize_diff_file(current))
			current = {
				"old_path": "",
				"new_path": "",
				"raw_lines": PackedStringArray(),
				"header_lines": PackedStringArray(),
				"hunks": [],
			}
			current_hunk_index = -1
		elif current.is_empty() and line.begins_with("--- "):
			current = {
				"old_path": "",
				"new_path": "",
				"raw_lines": PackedStringArray(),
				"header_lines": PackedStringArray(),
				"hunks": [],
			}
			current_hunk_index = -1
		if current.is_empty():
			continue
		var raw_lines: PackedStringArray = current["raw_lines"]
		raw_lines.append(line)
		current["raw_lines"] = raw_lines
		if line.begins_with("--- "):
			current["old_path"] = _clean_diff_path(line.substr(4))
		elif line.begins_with("+++ "):
			current["new_path"] = _clean_diff_path(line.substr(4))
		elif line.begins_with("rename from "):
			current["old_path"] = _clean_diff_path(line.substr(12))
		elif line.begins_with("rename to "):
			current["new_path"] = _clean_diff_path(line.substr(10))
		if line.begins_with("@@"):
			var hunks: Array = current["hunks"] as Array
			hunks.append(
				{
					"header": line,
					"lines": PackedStringArray([line]),
				}
			)
			current["hunks"] = hunks
			current_hunk_index = hunks.size() - 1
			continue
		if current_hunk_index >= 0:
			var hunks: Array = current["hunks"] as Array
			var hunk: Dictionary = hunks[current_hunk_index] as Dictionary
			var hunk_lines: PackedStringArray = hunk["lines"]
			hunk_lines.append(line)
			hunk["lines"] = hunk_lines
			hunks[current_hunk_index] = hunk
			current["hunks"] = hunks
		else:
			var header_lines: PackedStringArray = current["header_lines"]
			header_lines.append(line)
			current["header_lines"] = header_lines
	if not current.is_empty():
		files.append(_finalize_diff_file(current))
	return files


func _diff_status_text(status: String) -> String:
	match status:
		"added":
			return "Added"
		"deleted":
			return "Deleted"
		"renamed":
			return "Renamed"
		_:
			return "Modified"


func _diff_resolution_text(key: String, fallback: String) -> String:
	match str(_diff_resolution.get(key, "")):
		"accepted":
			return "Accepted"
		"reverted":
			return "Reverted"
		_:
			return fallback


func _populate_diff_tree(select_key := "") -> void:
	_diff_tree.clear()
	var root := _diff_tree.create_item()
	var first_item: TreeItem
	var selected_item: TreeItem
	for file_index in range(_diff_files.size()):
		var file: Dictionary = _diff_files[file_index] as Dictionary
		var file_key := "file:%d" % file_index
		var file_item := _diff_tree.create_item(root)
		file_item.set_text(0, str(file.get("path", "Unknown file")))
		file_item.set_text(
			1,
			_diff_resolution_text(
				file_key,
				_diff_status_text(str(file.get("status", "modified")))
			)
		)
		file_item.set_metadata(
			0,
			{"scope": "file", "file_index": file_index, "key": file_key}
		)
		file_item.set_collapsed(false)
		if first_item == null:
			first_item = file_item
		if file_key == select_key:
			selected_item = file_item
		var hunks: Array = file.get("hunks", []) as Array
		for hunk_index in range(hunks.size()):
			var hunk: Dictionary = hunks[hunk_index] as Dictionary
			var hunk_key := "hunk:%d:%d" % [file_index, hunk_index]
			var hunk_item := _diff_tree.create_item(file_item)
			hunk_item.set_text(0, str(hunk.get("summary", "Hunk")))
			hunk_item.set_text(
				1,
				_diff_resolution_text(hunk_key, "Pending")
			)
			hunk_item.set_metadata(
				0,
				{
					"scope": "hunk",
					"file_index": file_index,
					"hunk_index": hunk_index,
					"key": hunk_key,
				}
			)
			if hunk_key == select_key:
				selected_item = hunk_item
	var item_to_select := selected_item if selected_item != null else first_item
	if item_to_select != null:
		item_to_select.select(0)
		_on_diff_tree_selection_changed()
	else:
		_diff_view.text = _current_turn_diff
		_update_diff_action_buttons({})


func _selected_diff_data() -> Dictionary:
	var selected := _diff_tree.get_selected()
	if selected == null:
		return {}
	var metadata_value: Variant = selected.get_metadata(0)
	if typeof(metadata_value) != TYPE_DICTIONARY:
		return {}
	var metadata: Dictionary = metadata_value as Dictionary
	var file_index := int(metadata.get("file_index", -1))
	if file_index < 0 or file_index >= _diff_files.size():
		return {}
	var file: Dictionary = _diff_files[file_index] as Dictionary
	var result := metadata.duplicate(true)
	result["path"] = str(file.get("path", ""))
	result["status"] = str(file.get("status", "modified"))
	if str(metadata.get("scope", "")) == "hunk":
		var hunks: Array = file.get("hunks", []) as Array
		var hunk_index := int(metadata.get("hunk_index", -1))
		if hunk_index < 0 or hunk_index >= hunks.size():
			return {}
		var hunk: Dictionary = hunks[hunk_index] as Dictionary
		result["patch"] = str(hunk.get("patch", ""))
		result["line"] = int(hunk.get("line", 0))
		result["label"] = "%s · %s" % [
			result["path"],
			str(hunk.get("header", "Hunk")),
		]
	else:
		result["patch"] = str(file.get("patch", ""))
		var hunks: Array = file.get("hunks", []) as Array
		result["line"] = (
			int((hunks[0] as Dictionary).get("line", 0))
			if not hunks.is_empty()
			else 0
		)
		result["label"] = result["path"]
	return result


func _resource_path_for_diff(path: String) -> String:
	if path.is_empty():
		return ""
	if path.begins_with("res://"):
		return path
	return "res://" + path.trim_prefix("./")


func _on_diff_tree_selection_changed() -> void:
	var data := _selected_diff_data()
	if data.is_empty():
		_update_diff_action_buttons(data)
		return
	_diff_view.text = str(data.get("patch", ""))
	_diff_view.set_caret_line(0)
	_diff_view.set_caret_column(0)
	_update_diff_action_buttons(data)


func _update_diff_action_buttons(data: Dictionary) -> void:
	var has_selection := not data.is_empty()
	var key := str(data.get("key", ""))
	var resolution := str(_diff_resolution.get(key, ""))
	var resource_path := _resource_path_for_diff(str(data.get("path", "")))
	_diff_open_button.disabled = (
		not has_selection or not FileAccess.file_exists(resource_path)
	)
	_diff_copy_button.disabled = not has_selection
	_diff_accept_button.disabled = not has_selection or not resolution.is_empty()
	_diff_revert_button.disabled = not has_selection or not resolution.is_empty()
	_diff_run_button.disabled = _editor_interface == null


func _open_selected_diff_file() -> void:
	var data := _selected_diff_data()
	if data.is_empty():
		return
	_open_file_reference(
		_resource_path_for_diff(str(data.get("path", ""))),
		int(data.get("line", 0))
	)


func _copy_selected_diff_patch() -> void:
	var data := _selected_diff_data()
	if data.is_empty():
		return
	DisplayServer.clipboard_set(str(data.get("patch", "")))
	_append_activity("Selected Diff patch copied")


func _mark_diff_resolution(data: Dictionary, resolution: String) -> void:
	var key := str(data.get("key", ""))
	if key.is_empty():
		return
	_diff_resolution[key] = resolution
	if str(data.get("scope", "")) == "file":
		var file_index := int(data.get("file_index", -1))
		if file_index >= 0 and file_index < _diff_files.size():
			var file: Dictionary = _diff_files[file_index] as Dictionary
			var hunks: Array = file.get("hunks", []) as Array
			for hunk_index in range(hunks.size()):
				_diff_resolution[
					"hunk:%d:%d" % [file_index, hunk_index]
				] = resolution
	_populate_diff_tree(key)


func _accept_selected_diff() -> void:
	var data := _selected_diff_data()
	if data.is_empty():
		return
	_mark_diff_resolution(data, "accepted")
	_append_activity("Accepted: %s" % str(data.get("label", "Change")))


func _request_revert_selected_diff() -> void:
	var data := _selected_diff_data()
	if data.is_empty():
		return
	_pending_revert_patch = str(data.get("patch", ""))
	_pending_revert_key = str(data.get("key", ""))
	_pending_revert_label = str(data.get("label", "Change"))
	_diff_revert_confirmation.dialog_text = (
		"Revert the following change?\n\n%s\n\n"
		% _pending_revert_label
		+ "The plugin checks the reverse patch first and will not change files if the check fails."
	)
	if DisplayServer.get_name() != "headless":
		_diff_revert_confirmation.popup_centered(Vector2i(560, 250))


func _git_apply_reverse(patch: String, check_only: bool) -> Dictionary:
	var temp_directory := ProjectSettings.globalize_path(
		"res://.godot/godex"
	)
	var make_error := DirAccess.make_dir_recursive_absolute(temp_directory)
	if make_error != OK:
		return {
			"ok": false,
			"output": "Could not create the temporary patch directory: %s" % error_string(make_error),
		}
	var patch_path := temp_directory.path_join(
		"reverse_%d.patch" % Time.get_ticks_msec()
	)
	var patch_file := FileAccess.open(patch_path, FileAccess.WRITE)
	if patch_file == null:
		return {"ok": false, "output": "Could not write the temporary patch file."}
	patch_file.store_string(patch)
	patch_file.close()
	var arguments := PackedStringArray(
		[
			"-C",
			_project_cwd(),
			"apply",
			"--reverse",
			"--recount",
			"--whitespace=nowarn",
		]
	)
	if check_only:
		arguments.append("--check")
	arguments.append(patch_path)
	var output: Array = []
	var exit_code := OS.execute("git", arguments, output, true)
	DirAccess.remove_absolute(patch_path)
	var output_lines := PackedStringArray()
	for output_value in output:
		output_lines.append(str(output_value))
	return {
		"ok": exit_code == 0,
		"output": "\n".join(output_lines),
		"exit_code": exit_code,
	}


func _confirm_revert_selected_diff() -> void:
	if _pending_revert_patch.is_empty() or _pending_revert_key.is_empty():
		return
	var check_result := _git_apply_reverse(_pending_revert_patch, true)
	if not bool(check_result.get("ok", false)):
		_append_error(
			"Could not safely revert \"%s\". The file may have changed again, or Git may be unavailable.\n%s"
			% [
				_pending_revert_label,
				str(check_result.get("output", "")).strip_edges(),
			]
		)
		return
	var apply_result := _git_apply_reverse(_pending_revert_patch, false)
	if not bool(apply_result.get("ok", false)):
		_append_error(
			"Could not apply the reverse patch:\n%s"
			% str(apply_result.get("output", "")).strip_edges()
		)
		return
	var data := _selected_diff_data()
	if str(data.get("key", "")) != _pending_revert_key:
		data = {"key": _pending_revert_key}
	_mark_diff_resolution(data, "reverted")
	if _editor_interface != null:
		_editor_interface.get_resource_filesystem().scan()
	_append_activity("Reverted: %s" % _pending_revert_label)
	_pending_revert_patch = ""
	_pending_revert_key = ""
	_pending_revert_label = ""


func _load_model_list(initial_load := false) -> void:
	if _process_id < 0 or _stdio == null or _model_list_request_pending:
		return

	_waiting_for_initial_model_list = initial_load
	_model_list_request_pending = true
	_model_list_items.clear()
	_request_model_list_page("")
	_update_thread_controls()


func _request_model_list_page(cursor: String) -> void:
	var params := {
		"limit": 100,
		"includeHidden": false,
	}
	if not cursor.is_empty():
		params["cursor"] = cursor
	_send_request("model/list", params)


func _handle_model_list_response(result: Dictionary) -> void:
	var data_value: Variant = result.get("data", [])
	if typeof(data_value) == TYPE_ARRAY:
		var data: Array = data_value as Array
		for model_value in data:
			if typeof(model_value) == TYPE_DICTIONARY:
				_model_list_items.append(model_value)

	var next_cursor_value: Variant = result.get("nextCursor")
	var next_cursor := ""
	if next_cursor_value != null:
		next_cursor = str(next_cursor_value)
	if not next_cursor.is_empty():
		_request_model_list_page(next_cursor)
		return

	_model_list_request_pending = false
	_apply_model_list(_model_list_items)
	_model_list_items.clear()
	_finish_model_sync(true)


func _finish_model_sync(success: bool) -> void:
	var was_initial_load := _waiting_for_initial_model_list
	_waiting_for_initial_model_list = false
	_update_thread_controls()

	if was_initial_load:
		_load_thread_list()
	elif success:
		_append_activity("Model list synchronized with the current Codex installation")


func _selected_option_label(selector: OptionButton, fallback: String) -> String:
	if (
		is_instance_valid(selector)
		and selector.selected >= 0
		and selector.selected < selector.get_item_count()
	):
		return selector.get_item_text(selector.selected)
	return fallback


func _update_model_selector_presentation() -> void:
	if not is_instance_valid(_model_selector):
		return
	_configure_icon_button(
		_model_selector,
		&"Script",
		"◆",
		"Model: %s\nClick to select a model"
		% _selected_option_label(_model_selector, "Follow Codex configuration")
	)


func _update_effort_selector_presentation() -> void:
	if not is_instance_valid(_effort_selector):
		return
	_configure_icon_button(
		_effort_selector,
		&"Time",
		"◷",
		"Reasoning effort: %s\nClick to select reasoning effort"
		% _selected_option_label(_effort_selector, "Follow Codex configuration")
	)


func _update_skill_selector_presentation(status := "") -> void:
	if not is_instance_valid(_skills_selector):
		return
	var detail := status
	if detail.is_empty():
		if _attached_skill.is_empty():
			detail = "Click to use this for the next message"
		else:
			detail = "%s (selected for the next message)" % str(
				_attached_skill.get("name", "Skill")
			)
	_configure_icon_button(
		_skills_selector,
		&"RichTextEffect",
		"✦",
		"Skill: %s" % detail
	)


func _apply_model_list(models: Array) -> void:
	var previous_model_id := _selected_model_id
	var selected_index := 0
	var selected_model_found := previous_model_id.is_empty()
	var codex_default_display := ""
	_model_catalog.clear()
	_codex_default_model_id = ""

	for model_value in models:
		if typeof(model_value) != TYPE_DICTIONARY:
			continue
		var default_model: Dictionary = model_value as Dictionary
		if not bool(default_model.get("isDefault", false)):
			continue
		var default_id_value: Variant = default_model.get("id")
		if default_id_value != null:
			_codex_default_model_id = str(default_id_value)
		if _codex_default_model_id.is_empty():
			var default_model_value: Variant = default_model.get("model")
			if default_model_value != null:
				_codex_default_model_id = str(default_model_value)
		var default_display_value: Variant = default_model.get("displayName")
		if default_display_value != null:
			codex_default_display = str(default_display_value).strip_edges()
		if codex_default_display.is_empty():
			codex_default_display = _codex_default_model_id
		break

	_updating_model_selector = true
	_model_selector.clear()
	var follow_label := "Follow Codex configuration"
	if not codex_default_display.is_empty():
		follow_label += " (%s)" % codex_default_display
	_model_selector.add_item(follow_label)
	_model_selector.set_item_metadata(0, "")
	_model_selector.set_item_tooltip(
		0,
		"Use the default model from the current Codex configuration"
	)

	for model_value in models:
		if typeof(model_value) != TYPE_DICTIONARY:
			continue
		var model: Dictionary = model_value as Dictionary
		if bool(model.get("hidden", false)):
			continue

		var model_id := ""
		var model_id_value: Variant = model.get("id")
		if model_id_value != null:
			model_id = str(model_id_value)
		if model_id.is_empty():
			var model_value_id: Variant = model.get("model")
			if model_value_id != null:
				model_id = str(model_value_id)
		if model_id.is_empty():
			continue
		_model_catalog[model_id] = model

		var display_name := ""
		var display_name_value: Variant = model.get("displayName")
		if display_name_value != null:
			display_name = str(display_name_value).strip_edges()
		if display_name.is_empty():
			display_name = model_id
		if bool(model.get("isDefault", false)):
			display_name += " (Codex default)"

		_model_selector.add_item(display_name)
		var item_index := _model_selector.get_item_count() - 1
		_model_selector.set_item_metadata(item_index, model_id)
		_model_selector.set_item_tooltip(item_index, model_id)
		if model_id == previous_model_id:
			selected_index = item_index
			selected_model_found = true

	_model_selector.select(selected_index)
	_updating_model_selector = false
	_model_list_loaded = true

	if selected_model_found:
		_selected_model_id = previous_model_id
	else:
		_selected_model_id = ""
		_append_activity("The previously selected model is unavailable; now following Codex configuration")
	_update_model_selector_presentation()
	_update_effort_options()
	_save_settings()
	_update_thread_controls()


func _set_model_selector_placeholder(text: String) -> void:
	if not is_instance_valid(_model_selector):
		return
	_updating_model_selector = true
	_model_selector.clear()
	_model_selector.add_item(text)
	_model_selector.set_item_metadata(0, "")
	_model_selector.set_item_disabled(0, true)
	_model_selector.select(0)
	_updating_model_selector = false
	_update_model_selector_presentation()
	_update_thread_controls()


func _set_model_selector_fallback() -> void:
	if not is_instance_valid(_model_selector):
		return
	_updating_model_selector = true
	_model_selector.clear()
	_model_selector.add_item("Follow Codex configuration")
	_model_selector.set_item_metadata(0, "")
	_model_selector.set_item_tooltip(
		0,
		"Could not sync the model list; new conversations will use the current Codex configuration"
	)
	_model_selector.select(0)
	_updating_model_selector = false
	_selected_model_id = ""
	_model_list_loaded = false
	_model_catalog.clear()
	_codex_default_model_id = ""
	_selected_reasoning_effort = ""
	_update_model_selector_presentation()
	_set_effort_selector_fallback()
	_save_settings()
	_update_thread_controls()


func _selected_model() -> String:
	return _selected_model_id


func _selected_effort() -> String:
	return _selected_reasoning_effort


func _update_effort_options() -> void:
	if not is_instance_valid(_effort_selector):
		return

	var model_id := _selected_model_id
	if model_id.is_empty():
		model_id = _codex_default_model_id
	var model: Dictionary = _model_catalog.get(model_id, {}) as Dictionary
	var efforts_value: Variant = model.get("supportedReasoningEfforts", [])
	var efforts: Array = []
	if typeof(efforts_value) == TYPE_ARRAY:
		efforts = efforts_value as Array

	var previous_effort := _selected_reasoning_effort
	var selected_index := 0
	var selected_effort_found := previous_effort.is_empty()
	var default_effort := str(model.get("defaultReasoningEffort", ""))
	var follow_label := "Follow Codex configuration"
	if not default_effort.is_empty():
		follow_label += " (default: %s)" % default_effort

	_updating_effort_selector = true
	_effort_selector.clear()
	_effort_selector.add_item(follow_label)
	_effort_selector.set_item_metadata(0, "")
	_effort_selector.set_item_tooltip(0, "Use the selected model's default reasoning effort")

	for effort_value in efforts:
		if typeof(effort_value) != TYPE_DICTIONARY:
			continue
		var effort: Dictionary = effort_value as Dictionary
		var effort_id := str(effort.get("reasoningEffort", ""))
		if effort_id.is_empty():
			continue
		_effort_selector.add_item(effort_id)
		var effort_index := _effort_selector.get_item_count() - 1
		_effort_selector.set_item_metadata(effort_index, effort_id)
		_effort_selector.set_item_tooltip(
			effort_index,
			str(effort.get("description", effort_id))
		)
		if effort_id == previous_effort:
			selected_index = effort_index
			selected_effort_found = true

	_effort_selector.select(selected_index)
	_updating_effort_selector = false
	if selected_effort_found:
		_selected_reasoning_effort = previous_effort
	else:
		_selected_reasoning_effort = ""
		_append_activity("The current model does not support the previous reasoning effort; using its default")
	_update_effort_selector_presentation()
	_save_settings()
	_update_thread_controls()


func _set_effort_selector_placeholder(text: String) -> void:
	if not is_instance_valid(_effort_selector):
		return
	_updating_effort_selector = true
	_effort_selector.clear()
	_effort_selector.add_item(text)
	_effort_selector.set_item_metadata(0, "")
	_effort_selector.set_item_disabled(0, true)
	_effort_selector.select(0)
	_updating_effort_selector = false
	_update_effort_selector_presentation()
	_update_thread_controls()


func _set_effort_selector_fallback() -> void:
	if not is_instance_valid(_effort_selector):
		return
	_updating_effort_selector = true
	_effort_selector.clear()
	_effort_selector.add_item("Follow Codex configuration")
	_effort_selector.set_item_metadata(0, "")
	_effort_selector.set_item_tooltip(0, "Could not sync the model list; using the Codex default")
	_effort_selector.select(0)
	_updating_effort_selector = false
	_update_effort_selector_presentation()
	_update_thread_controls()


func _request_rate_limits() -> void:
	if _process_id < 0 or _stdio == null or _rate_limits_request_pending:
		return
	_rate_limits_request_pending = true
	_send_request("account/rateLimits/read")


func _dictionary_value(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


func _update_rate_limit_display() -> void:
	if not is_instance_valid(_rate_limit_button):
		return
	if _rate_limit_snapshot.is_empty():
		_rate_limit_button.text = "Usage --"
		_rate_limit_button.tooltip_text = (
			_rate_limit_error
			if not _rate_limit_error.is_empty()
			else "Codex account usage is not available"
		)
		return
	var snapshot := _dictionary_value(_rate_limit_snapshot.get("rateLimits"))
	var primary := _dictionary_value(snapshot.get("primary"))
	var secondary := _dictionary_value(snapshot.get("secondary"))
	var values := PackedStringArray()
	if not primary.is_empty():
		values.append("%d%%" % int(primary.get("usedPercent", 0)))
	if not secondary.is_empty():
		values.append("%d%%" % int(secondary.get("usedPercent", 0)))
	_rate_limit_button.text = "Usage %s" % ("/".join(values) if not values.is_empty() else "--")
	_rate_limit_button.tooltip_text = _rate_limit_details_text()


func _rate_limit_details_text() -> String:
	if _rate_limit_snapshot.is_empty():
		return (
			_rate_limit_error
			if not _rate_limit_error.is_empty()
			else "Account usage is not available."
		)
	var snapshot := _dictionary_value(_rate_limit_snapshot.get("rateLimits"))
	var lines := PackedStringArray()
	lines.append("Plan: %s" % str(snapshot.get("planType", "Unknown")))
	lines.append(_format_rate_limit_window("Primary window", snapshot.get("primary", {})))
	lines.append(_format_rate_limit_window("Secondary window", snapshot.get("secondary", {})))
	var credits := _dictionary_value(snapshot.get("credits"))
	if not credits.is_empty():
		if bool(credits.get("unlimited", false)):
			lines.append("Credits: unlimited")
		else:
			lines.append("Credit balance: %s" % str(credits.get("balance", "Unknown")))
	var reached_value: Variant = snapshot.get("rateLimitReachedType")
	if reached_value != null:
		lines.append("Limit reached: %s" % str(reached_value))
	return "\n".join(lines)


func _format_rate_limit_window(label: String, window_value: Variant) -> String:
	if typeof(window_value) != TYPE_DICTIONARY:
		return "%s: unavailable" % label
	var window: Dictionary = window_value as Dictionary
	if window.is_empty():
		return "%s: unavailable" % label
	var text := "%s: %d%% used" % [label, int(window.get("usedPercent", 0))]
	var resets_at_value: Variant = window.get("resetsAt")
	if resets_at_value != null:
		text += ", resets %s" % Time.get_datetime_string_from_unix_time(
			int(resets_at_value),
			true
		)
	return text


func _show_rate_limit_details() -> void:
	_show_inventory("Codex account usage", _rate_limit_details_text())


func _set_skills_placeholder(text: String) -> void:
	if not is_instance_valid(_skills_selector):
		return
	_skills_selector.clear()
	_skills_selector.add_item(text)
	_skills_selector.set_item_metadata(0, {})
	_skills_selector.set_item_disabled(0, true)
	_skills_selector.select(0)
	_update_skill_selector_presentation(text)
	_update_thread_controls()


func _load_skills(force_reload := false) -> void:
	if _process_id < 0 or _stdio == null:
		return
	_send_request(
		"skills/list",
		{
			"cwds": [_project_cwd()],
			"forceReload": force_reload,
		}
	)


func _apply_skills_response(result: Dictionary) -> void:
	_skills.clear()
	var data_value: Variant = result.get("data", [])
	if typeof(data_value) == TYPE_ARRAY:
		for entry_value in data_value as Array:
			if typeof(entry_value) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_value as Dictionary
			var skills_value: Variant = entry.get("skills", [])
			if typeof(skills_value) != TYPE_ARRAY:
				continue
			for skill_value in skills_value as Array:
				if (
					typeof(skill_value) == TYPE_DICTIONARY
					and bool((skill_value as Dictionary).get("enabled", true))
				):
					_skills.append((skill_value as Dictionary).duplicate(true))

	_skills.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return str(left.get("name", "")).naturalnocasecmp_to(
				str(right.get("name", ""))
			) < 0
	)
	_skills_selector.clear()
	if _skills.is_empty():
		_set_skills_placeholder("No Skills available")
		return
	for skill in _skills:
		var interface: Dictionary = skill.get("interface", {}) as Dictionary
		var display_name := str(interface.get("displayName", "")).strip_edges()
		if display_name.is_empty():
			display_name = str(skill.get("name", "Skill"))
		_skills_selector.add_item(
			"%s · %s" % [display_name, str(skill.get("scope", ""))]
		)
		_skills_selector.set_item_metadata(
			_skills_selector.get_item_count() - 1,
			skill
		)
	_skills_selector.select(0)
	_update_skill_selector_presentation()
	_update_thread_controls()


func _refresh_skills() -> void:
	_set_skills_placeholder("Syncing Skills…")
	_load_skills(true)


func _on_skill_selected(_index: int) -> void:
	_attach_selected_skill()


func _attach_selected_skill() -> void:
	if _skills_selector.selected < 0:
		return
	var metadata_value: Variant = _skills_selector.get_item_metadata(
		_skills_selector.selected
	)
	if typeof(metadata_value) != TYPE_DICTIONARY:
		return
	var skill: Dictionary = metadata_value as Dictionary
	var skill_name := str(skill.get("name", "")).strip_edges()
	var skill_path := str(skill.get("path", "")).strip_edges()
	if skill_name.is_empty() or skill_path.is_empty():
		return
	_attached_skill = {
		"name": skill_name,
		"path": skill_path,
	}
	var marker := "$%s" % skill_name
	if marker not in _input.text:
		_input.text = ("%s %s" % [marker, _input.text]).strip_edges() + " "
		_input.set_caret_line(_input.get_line_count() - 1)
		_input.set_caret_column(_input.get_line(_input.get_line_count() - 1).length())
	_update_skill_selector_presentation()
	_append_activity("Attached Skill: %s" % skill_name)


func _on_tool_action_selected(action_id: int) -> void:
	match action_id:
		ToolAction.REVIEW_UNCOMMITTED:
			_start_uncommitted_review()
		ToolAction.COMPACT_CONTEXT:
			if DisplayServer.get_name() != "headless":
				_compact_confirmation.popup_centered(Vector2i(520, 220))
		ToolAction.MCP_STATUS:
			_request_mcp_status()
		ToolAction.RECONNECT:
			_connect_server()
		ToolAction.SETTINGS:
			_show_settings_dialog()


func _update_tools_menu() -> void:
	var popup := _tools_button.get_popup()
	var can_run_turn_action := (
		_state == ConnectionState.READY
		and not _thread_id.is_empty()
		and not _show_archived_threads
	)
	popup.set_item_disabled(
		popup.get_item_index(ToolAction.REVIEW_UNCOMMITTED),
		not can_run_turn_action
	)
	popup.set_item_disabled(
		popup.get_item_index(ToolAction.COMPACT_CONTEXT),
		not can_run_turn_action
	)
	popup.set_item_disabled(
		popup.get_item_index(ToolAction.MCP_STATUS),
		_process_id < 0
	)
	popup.set_item_disabled(
		popup.get_item_index(ToolAction.RECONNECT),
		_state in [
			ConnectionState.STARTING,
			ConnectionState.STARTING_THREAD,
			ConnectionState.TURN_RUNNING,
		]
	)


func _copy_option_items(source: OptionButton, target: OptionButton) -> void:
	target.clear()
	for item_index in range(source.get_item_count()):
		target.add_item(source.get_item_text(item_index))
		var target_index := target.get_item_count() - 1
		target.set_item_metadata(target_index, source.get_item_metadata(item_index))
		target.set_item_disabled(target_index, source.is_item_disabled(item_index))
		target.set_item_tooltip(target_index, source.get_item_tooltip(item_index))


func _select_option_by_metadata(selector: OptionButton, metadata: String) -> bool:
	for item_index in range(selector.get_item_count()):
		if str(selector.get_item_metadata(item_index)) == metadata:
			selector.select(item_index)
			return true
	if selector.get_item_count() > 0:
		selector.select(0)
	return false


func _populate_settings_model_selector() -> void:
	_copy_option_items(_model_selector, _settings_model_selector)
	_select_option_by_metadata(_settings_model_selector, _selected_model_id)


func _populate_settings_effort_selector(
	model_id: String,
	selected_effort: String
) -> void:
	_settings_effort_selector.clear()
	var effective_model_id := model_id
	if effective_model_id.is_empty():
		effective_model_id = _codex_default_model_id
	var model: Dictionary = _model_catalog.get(effective_model_id, {}) as Dictionary
	var default_effort := str(model.get("defaultReasoningEffort", ""))
	var follow_label := "Follow Codex configuration"
	if not default_effort.is_empty():
		follow_label += " (default: %s)" % default_effort
	_settings_effort_selector.add_item(follow_label)
	_settings_effort_selector.set_item_metadata(0, "")
	var selected_index := 0
	var efforts_value: Variant = model.get("supportedReasoningEfforts", [])
	if typeof(efforts_value) == TYPE_ARRAY:
		for effort_value in efforts_value as Array:
			if typeof(effort_value) != TYPE_DICTIONARY:
				continue
			var effort: Dictionary = effort_value as Dictionary
			var effort_id := str(effort.get("reasoningEffort", ""))
			if effort_id.is_empty():
				continue
			_settings_effort_selector.add_item(effort_id)
			var item_index := _settings_effort_selector.get_item_count() - 1
			_settings_effort_selector.set_item_metadata(item_index, effort_id)
			_settings_effort_selector.set_item_tooltip(
				item_index,
				str(effort.get("description", effort_id))
			)
			if effort_id == selected_effort:
				selected_index = item_index
	_settings_effort_selector.select(selected_index)


func _on_settings_model_selected(index: int) -> void:
	if index < 0 or index >= _settings_model_selector.get_item_count():
		return
	var model_id := str(_settings_model_selector.get_item_metadata(index))
	var selected_effort := ""
	if (
		_settings_effort_selector.selected >= 0
		and _settings_effort_selector.selected
		< _settings_effort_selector.get_item_count()
	):
		selected_effort = str(
			_settings_effort_selector.get_item_metadata(
				_settings_effort_selector.selected
			)
		)
	_populate_settings_effort_selector(model_id, selected_effort)


func _connection_state_name() -> String:
	match _state:
		ConnectionState.STARTING:
			return "Starting"
		ConnectionState.STARTING_THREAD:
			return "Loading conversation"
		ConnectionState.READY:
			return "Connected"
		ConnectionState.TURN_RUNNING:
			return "Godex is working"
		ConnectionState.ERROR:
			return "Error"
		_:
			return "Disconnected"


func _settings_diagnostic_text() -> String:
	var lines := PackedStringArray()
	lines.append("Plugin version: %s" % CLIENT_VERSION)
	lines.append("Connection status: %s" % _connection_state_name())
	lines.append("Process ID: %s" % ("--" if _process_id < 0 else str(_process_id)))
	lines.append("Current conversation: %s" % ("--" if _thread_id.is_empty() else _thread_id))
	lines.append(
		"Model: %s"
		% (
			"Follow Codex configuration"
			if _selected_model_id.is_empty()
			else _selected_model_id
		)
	)
	lines.append(
		"Reasoning effort: %s"
		% (
			"Follow model default"
			if _selected_reasoning_effort.is_empty()
			else _selected_reasoning_effort
		)
	)
	lines.append("Skills: %d available" % _skills.size())
	lines.append(
		"Permission: %s"
		% ("Allow project changes" if _allow_edits_check.button_pressed else "Read-only")
	)
	lines.append(
		"Automatic reconnect: %s, maximum %d attempts"
		% [
			"Enabled" if _auto_reconnect_enabled else "Disabled",
			_auto_reconnect_max_attempts,
		]
	)
	if not _stderr_text.strip_edges().is_empty():
		lines.append("\nRecent App Server stderr:")
		lines.append(_summarize_diagnostic(_stderr_text))
	if not _connection_events.is_empty():
		lines.append("\nRecent connection events:")
		var first_index := maxi(_connection_events.size() - 20, 0)
		for event_index in range(first_index, _connection_events.size()):
			lines.append(_connection_events[event_index])
	return "\n".join(lines)


func _show_settings_dialog() -> void:
	_settings_path_edit.text = _path_edit.text
	_settings_allow_edits_check.button_pressed = _allow_edits_check.button_pressed
	_settings_auto_reconnect_check.button_pressed = _auto_reconnect_enabled
	_settings_max_reconnect_spin.value = _auto_reconnect_max_attempts
	_populate_settings_model_selector()
	_populate_settings_effort_selector(
		_selected_model_id,
		_selected_reasoning_effort
	)
	_settings_status_view.text = _settings_diagnostic_text()
	_settings_status_view.set_caret_line(0)
	_settings_status_view.set_caret_column(0)
	if DisplayServer.get_name() != "headless":
		_settings_dialog.popup_centered(Vector2i(760, 650))


func _settings_selected_metadata(selector: OptionButton) -> String:
	if selector.selected < 0 or selector.selected >= selector.get_item_count():
		return ""
	return str(selector.get_item_metadata(selector.selected))


func _apply_settings_dialog() -> void:
	_path_edit.text = _settings_path_edit.text.strip_edges()
	_allow_edits_check.set_pressed_no_signal(
		_settings_allow_edits_check.button_pressed
	)
	_auto_reconnect_enabled = _settings_auto_reconnect_check.button_pressed
	_auto_reconnect_max_attempts = int(_settings_max_reconnect_spin.value)
	_selected_model_id = _settings_selected_metadata(_settings_model_selector)
	_selected_reasoning_effort = _settings_selected_metadata(
		_settings_effort_selector
	)
	_select_option_by_metadata(_model_selector, _selected_model_id)
	_update_model_selector_presentation()
	_update_effort_options()
	_update_policy_label()
	_save_settings()
	_settings_status_view.text = _settings_diagnostic_text()
	_append_activity("Godex settings saved")


func _apply_settings_and_reconnect() -> void:
	_apply_settings_dialog()
	_settings_dialog.hide()
	_connect_server()


func _settings_payload_from_dialog() -> Dictionary:
	return {
		"format": "godex-settings",
		"version": 1,
		"executable_path": _settings_path_edit.text.strip_edges(),
		"allow_project_edits": _settings_allow_edits_check.button_pressed,
		"selected_model_id": _settings_selected_metadata(
			_settings_model_selector
		),
		"selected_reasoning_effort": _settings_selected_metadata(
			_settings_effort_selector
		),
		"auto_reconnect_enabled": _settings_auto_reconnect_check.button_pressed,
		"auto_reconnect_max_attempts": int(
			_settings_max_reconnect_spin.value
		),
	}


func _export_settings() -> void:
	_settings_file_mode = "export"
	_settings_file_dialog.title = "Export Godex settings"
	_settings_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_settings_file_dialog.current_file = "godex-settings.json"
	if DisplayServer.get_name() != "headless":
		_settings_file_dialog.popup_centered_ratio(0.7)


func _import_settings() -> void:
	_settings_file_mode = "import"
	_settings_file_dialog.title = "Import Godex settings"
	_settings_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	if DisplayServer.get_name() != "headless":
		_settings_file_dialog.popup_centered_ratio(0.7)


func _on_settings_file_selected(path: String) -> void:
	if _settings_file_mode == "export":
		var output := FileAccess.open(path, FileAccess.WRITE)
		if output == null:
			_append_error("Could not export settings: %s" % path)
			return
		output.store_string(JSON.stringify(_settings_payload_from_dialog(), "  "))
		output.close()
		_append_activity("Settings exported: %s" % path)
		return
	if _settings_file_mode != "import":
		return
	var input := FileAccess.open(path, FileAccess.READ)
	if input == null:
		_append_error("Could not read settings: %s" % path)
		return
	var parser := JSON.new()
	var parse_error := parser.parse(input.get_as_text())
	input.close()
	if parse_error != OK or typeof(parser.data) != TYPE_DICTIONARY:
		_append_error("The settings file is not valid Godex JSON.")
		return
	var payload: Dictionary = parser.data as Dictionary
	if str(payload.get("format", "")) not in ["godex-settings", "codex-dock-settings"]:
		_append_error("The settings file format is not supported.")
		return
	_settings_path_edit.text = str(payload.get("executable_path", ""))
	_settings_allow_edits_check.button_pressed = bool(
		payload.get("allow_project_edits", true)
	)
	_settings_auto_reconnect_check.button_pressed = bool(
		payload.get("auto_reconnect_enabled", true)
	)
	_settings_max_reconnect_spin.value = clampi(
		int(payload.get("auto_reconnect_max_attempts", 5)),
		1,
		20
	)
	var model_id := str(payload.get("selected_model_id", ""))
	var effort_id := str(payload.get("selected_reasoning_effort", ""))
	_select_option_by_metadata(_settings_model_selector, model_id)
	_populate_settings_effort_selector(model_id, effort_id)
	_append_activity("Settings loaded; choose Save to apply them")


func _start_uncommitted_review() -> void:
	if (
		_thread_id.is_empty()
		or _show_archived_threads
		or _state != ConnectionState.READY
	):
		return
	_assistant_received_text = false
	_assistant_stream_text = ""
	_clear_current_diff()
	_set_state(ConnectionState.TURN_RUNNING, "Starting code review…")
	_append_system_message("Reviewing uncommitted changes in the current project…")
	_send_request(
		"review/start",
		{
			"threadId": _thread_id,
			"delivery": "inline",
			"target": {"type": "uncommittedChanges"},
		}
	)


func _start_context_compaction() -> void:
	if (
		_thread_id.is_empty()
		or _show_archived_threads
		or _state != ConnectionState.READY
	):
		return
	_assistant_received_text = false
	_assistant_stream_text = ""
	_set_state(ConnectionState.TURN_RUNNING, "Compacting conversation context…")
	_send_request("thread/compact/start", {"threadId": _thread_id})


func _request_mcp_status() -> void:
	if _process_id < 0 or _stdio == null:
		return
	_show_inventory("MCP status", "Reading MCP server status…")
	var params: Dictionary = {
		"limit": 100,
		"detail": "toolsAndAuthOnly",
	}
	if not _thread_id.is_empty() and not _show_archived_threads:
		params["threadId"] = _thread_id
	_send_request("mcpServerStatus/list", params)


func _show_mcp_status_response(result: Dictionary) -> void:
	var lines := PackedStringArray()
	var data_value: Variant = result.get("data", [])
	if typeof(data_value) == TYPE_ARRAY:
		for server_value in data_value as Array:
			if typeof(server_value) != TYPE_DICTIONARY:
				continue
			var server: Dictionary = server_value as Dictionary
			var tools: Dictionary = server.get("tools", {}) as Dictionary
			lines.append(
				"%s\n  Login: %s\n  Tools: %d"
				% [
					str(server.get("name", "MCP")),
					str(server.get("authStatus", "unknown")),
					tools.size(),
				]
			)
			if not tools.is_empty():
				var tool_names := PackedStringArray()
				for tool_name in tools.keys():
					tool_names.append(str(tool_name))
				tool_names.sort()
				lines.append("  %s" % ", ".join(tool_names))
	if lines.is_empty():
		lines.append("No MCP servers are configured for the current conversation.")
	_show_inventory("MCP status", "\n\n".join(lines))


func _show_inventory(title: String, text: String) -> void:
	_inventory_dialog.title = title
	_inventory_view.text = text
	_inventory_view.set_caret_line(0)
	_inventory_view.set_caret_column(0)
	if DisplayServer.get_name() != "headless":
		_inventory_dialog.popup_centered(Vector2i(740, 500))


func _load_thread_list() -> void:
	if _process_id < 0 or _stdio == null:
		return
	if _thread_list_request_pending:
		_thread_list_reload_queued = true
		return
	if _thread_id.is_empty():
		_set_state(ConnectionState.STARTING_THREAD, "Loading conversation history…")
	_thread_list_request_pending = true
	var list_params: Dictionary = {
		"archived": _show_archived_threads,
		"cwd": _project_cwd(),
		"limit": 50,
		"sortKey": "recency_at",
		"sortDirection": "desc",
	}
	_send_request(
		"thread/list",
		list_params
	)


func _handle_thread_list_response(result: Dictionary) -> void:
	_thread_list_request_pending = false
	if _thread_list_reload_queued:
		_thread_list_reload_queued = false
		_load_thread_list()
		return
	var data_value: Variant = result.get("data", [])
	var threads: Array = []
	if typeof(data_value) == TYPE_ARRAY:
		threads = data_value as Array
	_thread_list_cache.clear()
	for thread_value in threads:
		if typeof(thread_value) == TYPE_DICTIONARY:
			_thread_list_cache.append(
				_thread_list_summary(thread_value as Dictionary)
			)
	_apply_thread_list(_thread_list_cache)

	if not _resume_after_thread_list_id.is_empty():
		var resume_thread_id := _resume_after_thread_list_id
		_resume_after_thread_list_id = ""
		_resume_thread(resume_thread_id)
		return

	if _show_archived_threads:
		_set_state(ConnectionState.READY, "Viewing archive")
		if _first_thread_id().is_empty():
			_clear_transcript()
			_append_system_message("No matching conversations were found in the archive.")
		return
		if _thread_id.is_empty() or not _select_thread_by_id(_thread_id):
			_thread_id = _first_thread_id()
			_send_request(
				"thread/read",
				{"threadId": _thread_id, "includeTurns": true}
			)
		return

	if _create_new_after_connect:
		_create_new_after_connect = false
		_start_thread()
		return

	if _thread_id.is_empty():
		var first_thread_id := _first_thread_id()
		if first_thread_id.is_empty():
			_clear_transcript()
			_append_system_message("This project has no previous conversations yet.")
			_start_thread()
		else:
			_resume_thread(first_thread_id)
	else:
		if _select_thread_by_id(_thread_id):
			_set_state(ConnectionState.READY, "Connected")
			_flush_pending_prompt()
			_flush_followup_queue()
		else:
			_thread_id = ""
			var fallback_thread_id := _first_thread_id()
			if fallback_thread_id.is_empty():
				_start_thread()
			else:
				_resume_thread(fallback_thread_id)


func _apply_thread_list(threads: Array) -> void:
	var current_thread_id := _thread_id
	_updating_thread_selector = true
	_thread_selector.clear()

	for thread_value in threads:
		if typeof(thread_value) != TYPE_DICTIONARY:
			continue
		var thread: Dictionary = thread_value as Dictionary
		var listed_thread_id := str(thread.get("id", ""))
		if listed_thread_id.is_empty():
			continue
		_thread_selector.add_item(_thread_display_name(thread))
		var item_index := _thread_selector.get_item_count() - 1
		_thread_selector.set_item_metadata(item_index, listed_thread_id)

	if _thread_selector.get_item_count() == 0:
		_thread_selector.add_item("No conversation history")
		_thread_selector.set_item_metadata(0, "")
		_thread_selector.set_item_disabled(0, true)
		_thread_selector.select(0)
	elif not current_thread_id.is_empty():
		_select_thread_by_id(current_thread_id)
	else:
		_thread_selector.select(0)

	_updating_thread_selector = false
	_update_thread_controls()


func _set_thread_selector_placeholder(text: String) -> void:
	if not is_instance_valid(_thread_selector):
		return
	_updating_thread_selector = true
	_thread_selector.clear()
	_thread_selector.add_item(text)
	_thread_selector.set_item_metadata(0, "")
	_thread_selector.set_item_disabled(0, true)
	_thread_selector.select(0)
	_updating_thread_selector = false
	_update_thread_controls()


func _thread_display_name(thread: Dictionary) -> String:
	var title := ""
	var name_value: Variant = thread.get("name")
	if name_value != null:
		title = str(name_value).strip_edges()
	if title.is_empty():
		var preview_value: Variant = thread.get("preview")
		if preview_value != null:
			title = str(preview_value).strip_edges()
	title = title.replace("\r", " ").replace("\n", " ")
	while "  " in title:
		title = title.replace("  ", " ")
	if title.is_empty():
		title = "New conversation"
	if title.length() > 38:
		title = title.left(37) + "…"
	return title


func _thread_list_summary(thread: Dictionary) -> Dictionary:
	return {
		"id": str(thread.get("id", "")),
		"name": thread.get("name"),
		"preview": thread.get("preview"),
		"archived": bool(thread.get("archived", false)),
	}


func _first_thread_id() -> String:
	if not is_instance_valid(_thread_selector):
		return ""
	for item_index in range(_thread_selector.get_item_count()):
		var item_thread_id := str(_thread_selector.get_item_metadata(item_index))
		if not item_thread_id.is_empty():
			return item_thread_id
	return ""


func _selected_thread_id() -> String:
	if not is_instance_valid(_thread_selector):
		return ""
	var selected_index := _thread_selector.selected
	if selected_index < 0 or selected_index >= _thread_selector.get_item_count():
		return ""
	return str(_thread_selector.get_item_metadata(selected_index))


func _select_thread_by_id(thread_id: String) -> bool:
	if not is_instance_valid(_thread_selector) or thread_id.is_empty():
		return false
	for item_index in range(_thread_selector.get_item_count()):
		if str(_thread_selector.get_item_metadata(item_index)) == thread_id:
			_thread_selector.select(item_index)
			_update_thread_controls()
			return true
	return false


func _ensure_thread_option(thread: Dictionary) -> void:
	if not is_instance_valid(_thread_selector):
		return
	var option_thread_id := str(thread.get("id", ""))
	if option_thread_id.is_empty():
		return
	var option_summary := _thread_list_summary(thread)
	var cache_contains_thread := false
	for cache_index in range(_thread_list_cache.size()):
		var cached_value: Variant = _thread_list_cache[cache_index]
		if typeof(cached_value) != TYPE_DICTIONARY:
			continue
		var cached_thread: Dictionary = cached_value as Dictionary
		if str(cached_thread.get("id", "")) == option_thread_id:
			_thread_list_cache[cache_index] = option_summary
			cache_contains_thread = true
			break
	if not cache_contains_thread and not _show_archived_threads:
		_thread_list_cache.push_front(option_summary)

	var option_title := _thread_display_name(thread)
	for item_index in range(_thread_selector.get_item_count()):
		if str(_thread_selector.get_item_metadata(item_index)) == option_thread_id:
			_thread_selector.set_item_text(item_index, option_title)
			return

	if _first_thread_id().is_empty():
		_thread_selector.clear()
	_thread_selector.add_item(option_title)
	var new_index := _thread_selector.get_item_count() - 1
	_thread_selector.set_item_metadata(new_index, option_thread_id)
	_update_thread_controls()


func _update_thread_option_title(thread_id: String, new_title: String) -> void:
	if thread_id.is_empty() or new_title.strip_edges().is_empty():
		return
	var display_title := new_title.strip_edges().replace("\r", " ").replace("\n", " ")
	if display_title.length() > 38:
		display_title = display_title.left(37) + "…"
	for thread_value in _thread_list_cache:
		if typeof(thread_value) != TYPE_DICTIONARY:
			continue
		var cached_thread: Dictionary = thread_value as Dictionary
		if str(cached_thread.get("id", "")) == thread_id:
			cached_thread["name"] = new_title.strip_edges()
			break
	for item_index in range(_thread_selector.get_item_count()):
		if str(_thread_selector.get_item_metadata(item_index)) == thread_id:
			_thread_selector.set_item_text(item_index, display_title)
			return


func _remove_thread_option(thread_id: String) -> void:
	if not is_instance_valid(_thread_selector) or thread_id.is_empty():
		return

	_updating_thread_selector = true
	for item_index in range(_thread_selector.get_item_count() - 1, -1, -1):
		if str(_thread_selector.get_item_metadata(item_index)) == thread_id:
			_thread_selector.remove_item(item_index)

	if _thread_selector.get_item_count() == 0:
		_thread_selector.add_item("No conversation history")
		_thread_selector.set_item_metadata(0, "")
		_thread_selector.set_item_disabled(0, true)
		_thread_selector.select(0)
	elif not _thread_id.is_empty():
		_select_thread_by_id(_thread_id)
	else:
		_thread_selector.select(0)
	_updating_thread_selector = false
	_update_thread_controls()


func _resume_thread(thread_id: String) -> void:
	if thread_id.is_empty() or _process_id < 0:
		return
	_switch_composer_state(thread_id)
	_pending_resume_thread_id = thread_id
	_turn_id = ""
	_assistant_received_text = false
	_assistant_stream_text = ""
	_clear_current_diff()
	_set_state(ConnectionState.STARTING_THREAD, "Resuming conversation…")
	var sandbox_mode := "workspace-write" if _allow_edits_check.button_pressed else "read-only"
	var resume_params: Dictionary = {
		"threadId": thread_id,
		"cwd": _project_cwd(),
		"sandbox": sandbox_mode,
		"approvalPolicy": "on-request",
	}
	var model_id := _selected_model()
	if not model_id.is_empty():
		resume_params["model"] = model_id
	_send_request("thread/resume", resume_params)


func _render_thread_history(
	thread: Dictionary,
	preserve_reader_state := false
) -> void:
	var previous_scroll := 0.0
	if is_instance_valid(_transcript):
		previous_scroll = _transcript.get_v_scroll_bar().value
	var previous_following := _transcript_following
	var previous_unseen_content := _transcript_has_unseen_content
	_transcript_render_suspended = true
	_clear_transcript()
	var rendered_message := false
	var turns_value: Variant = thread.get("turns", [])
	if typeof(turns_value) != TYPE_ARRAY:
		_append_system_message("This conversation has no history to display.")
		_finish_thread_history_render(
			preserve_reader_state,
			previous_scroll,
			previous_following,
			previous_unseen_content
		)
		return

	var turns: Array = turns_value as Array
	for turn_value in turns:
		if typeof(turn_value) != TYPE_DICTIONARY:
			continue
		var turn: Dictionary = turn_value as Dictionary
		var items_value: Variant = turn.get("items", [])
		if typeof(items_value) != TYPE_ARRAY:
			continue
		var items: Array = items_value as Array
		for item_value in items:
			if typeof(item_value) != TYPE_DICTIONARY:
				continue
			var item: Dictionary = item_value as Dictionary
			var item_type := str(item.get("type", ""))
			if item_type == "userMessage":
				var user_text := _user_message_text(item)
				if not user_text.is_empty():
					_append_user_message(_strip_legacy_editor_context(user_text))
					rendered_message = true
			elif item_type == "agentMessage":
				var agent_text := str(item.get("text", ""))
				if not agent_text.is_empty():
					_append_assistant_message(agent_text)
					rendered_message = true
			elif item_type == "plan":
				var plan_text := str(item.get("text", ""))
				if not plan_text.is_empty():
					_set_plan_text(plan_text)
					rendered_message = true
			elif item_type in [
				"commandExecution",
				"fileChange",
				"mcpToolCall",
				"dynamicToolCall",
				"webSearch",
			]:
				_upsert_tool_card(item, "completed")
				rendered_message = true
			elif _is_generated_image_item(item):
				_upsert_tool_card(item, "completed")
				rendered_message = true

	if not rendered_message:
		_append_system_message("This conversation has no messages yet.")
	_assistant_received_text = false
	_assistant_stream_text = ""
	_finish_thread_history_render(
		preserve_reader_state,
		previous_scroll,
		previous_following,
		previous_unseen_content
	)


func _finish_thread_history_render(
	preserve_reader_state: bool,
	previous_scroll: float,
	previous_following: bool,
	previous_unseen_content: bool
) -> void:
	_transcript_render_suspended = false
	if preserve_reader_state:
		_transcript_following = previous_following
		_next_transcript_scroll_restore = previous_scroll
		_transcript_render_has_new_content = (
			_transcript_render_has_new_content
			or previous_unseen_content
			or not previous_following
		)
	_collecting_history_images = true
	_request_transcript_render(true, false)
	_collecting_history_images = false


func _user_message_text(item: Dictionary) -> String:
	var parts := PackedStringArray()
	var content_value: Variant = item.get("content", [])
	if typeof(content_value) != TYPE_ARRAY:
		return ""
	var content: Array = content_value as Array
	for content_item_value in content:
		if typeof(content_item_value) != TYPE_DICTIONARY:
			continue
		var content_item: Dictionary = content_item_value as Dictionary
		if str(content_item.get("type", "")) == "text":
			var text := str(content_item.get("text", ""))
			if not text.is_empty():
				parts.append(text)
	return "\n".join(parts)


func _start_thread() -> void:
	_create_new_after_connect = false
	_show_archived_threads = false
	_thread_id = ""
	_turn_id = ""
	_assistant_received_text = false
	_assistant_stream_text = ""
	_clear_current_diff()
	_set_state(ConnectionState.STARTING_THREAD, "Loading project context…")

	var sandbox_mode := "workspace-write" if _allow_edits_check.button_pressed else "read-only"
	var start_params: Dictionary = {
		"cwd": _project_cwd(),
		"sandbox": sandbox_mode,
		"approvalPolicy": "on-request",
		"ephemeral": false,
	}
	var model_id := _selected_model()
	if not model_id.is_empty():
		start_params["model"] = model_id
	_send_request("thread/start", start_params)


func _project_cwd() -> String:
	var project_path := ProjectSettings.globalize_path("res://").simplify_path()
	if OS.get_name() == "Windows":
		project_path = project_path.replace("/", "\\")
	return project_path


func _toggle_current_scene() -> void:
	if _editor_interface == null:
		_append_error("The Godot editor interface is unavailable.")
		return
	if _editor_interface.is_playing_scene():
		_editor_interface.stop_playing_scene()
		_append_activity("Stopped the running scene")
		return
	if _editor_interface.get_edited_scene_root() == null:
		_append_activity("There is no scene available to run.")
		return
	_editor_interface.play_current_scene()
	_append_activity("Running the current scene")


func _update_run_scene_button() -> void:
	if not is_instance_valid(_run_scene_button):
		return
	if _editor_interface == null:
		if not _run_scene_button_state_initialized or not _run_scene_button.disabled:
			_run_scene_button.disabled = true
			_run_scene_button_state_initialized = true
		return
	var is_playing := _editor_interface.is_playing_scene()
	if (
		_run_scene_button_state_initialized
		and _run_scene_button_is_playing == is_playing
		and not _run_scene_button.disabled
	):
		return
	_run_scene_button_state_initialized = true
	_run_scene_button_is_playing = is_playing
	_run_scene_button.disabled = false
	var icon_texture := _editor_icon(&"Stop" if is_playing else &"Play")
	_run_scene_button.icon = icon_texture
	_run_scene_button.text = (
		("■" if is_playing else "▶")
		if icon_texture == null
		else ""
	)
	_run_scene_button.tooltip_text = (
		"Stop the currently running scene"
		if is_playing
		else "Run the current scene"
	)


func _clear_pending_skill() -> void:
	_attached_skill.clear()
	_update_skill_selector_presentation()


func _strip_legacy_editor_context(prompt: String) -> String:
	const LEGACY_BEGIN := "<godot-editor-context>\n"
	const LEGACY_END := "\n</godot-editor-context>\n\n"
	if not prompt.begins_with(LEGACY_BEGIN):
		return prompt
	var context_end_index := prompt.find(LEGACY_END)
	if context_end_index < 0:
		return prompt
	return prompt.substr(context_end_index + LEGACY_END.length())


func _composer_state_key(thread_id: String) -> String:
	return "thread:" + thread_id if not thread_id.is_empty() else "__new__"


func _current_composer_state_key() -> String:
	return _composer_state_key(_active_composer_thread_id)


func _store_current_composer_state_in_memory() -> void:
	if not is_instance_valid(_input):
		return
	var state_key := _current_composer_state_key()
	var draft := _input.text
	if draft.is_empty():
		_drafts_by_thread.erase(state_key)
	else:
		_drafts_by_thread[state_key] = draft
	if _followup_queue.is_empty():
		_followup_queues_by_thread.erase(state_key)
	else:
		_followup_queues_by_thread[state_key] = _followup_queue.duplicate(true)


func _load_composer_state(thread_id: String) -> void:
	_active_composer_thread_id = thread_id
	var state_key := _current_composer_state_key()
	_followup_queue.clear()
	var queue_value: Variant = _followup_queues_by_thread.get(state_key, [])
	if typeof(queue_value) == TYPE_ARRAY:
		for item_value in queue_value as Array:
			if typeof(item_value) != TYPE_DICTIONARY:
				continue
			var item: Dictionary = item_value as Dictionary
			var prompt := str(item.get("prompt", "")).strip_edges()
			if prompt.is_empty():
				continue
			_followup_queue.append(
				{
					"prompt": prompt,
					"skill": (
						(item.get("skill", {}) as Dictionary).duplicate(true)
						if typeof(item.get("skill", {})) == TYPE_DICTIONARY
						else {}
					),
				}
			)
	_composer_state_updates_suspended = true
	_input.text = str(_drafts_by_thread.get(state_key, ""))
	_input.set_caret_line(maxi(_input.get_line_count() - 1, 0))
	_input.set_caret_column(
		_input.get_line(_input.get_caret_line()).length()
	)
	_composer_state_updates_suspended = false
	_prompt_history_cursor = -1
	_prompt_history_draft = ""
	_render_followup_queue()
	_update_composer_actions()


func _switch_composer_state(thread_id: String) -> void:
	if thread_id == _active_composer_thread_id:
		return
	_store_current_composer_state_in_memory()
	_save_settings()
	_load_composer_state(thread_id)


func _adopt_new_thread_composer_state(thread_id: String) -> void:
	if thread_id.is_empty():
		return
	var old_key := _current_composer_state_key()
	_store_current_composer_state_in_memory()
	var new_key := _composer_state_key(thread_id)
	if old_key == "__new__":
		if _drafts_by_thread.has(old_key):
			_drafts_by_thread[new_key] = _drafts_by_thread[old_key]
		if _followup_queues_by_thread.has(old_key):
			_followup_queues_by_thread[new_key] = (
				_followup_queues_by_thread[old_key]
			)
		_drafts_by_thread.erase(old_key)
		_followup_queues_by_thread.erase(old_key)
	_load_composer_state(thread_id)
	_save_settings()


func _remove_composer_state(thread_id: String) -> void:
	var state_key := _composer_state_key(thread_id)
	_drafts_by_thread.erase(state_key)
	_followup_queues_by_thread.erase(state_key)
	_prompt_history_by_thread.erase(state_key)
	if _active_composer_thread_id == thread_id:
		_load_composer_state("")
	_save_settings()


func _on_input_text_changed() -> void:
	_update_composer_actions()
	if _composer_state_updates_suspended:
		return
	_prompt_history_cursor = -1
	_prompt_history_draft = ""
	_store_current_composer_state_in_memory()
	if is_instance_valid(_composer_save_timer):
		_composer_save_timer.start()


func _persist_composer_state() -> void:
	_store_current_composer_state_in_memory()
	_save_settings()


func _set_composer_text(text: String, preserve_history_cursor := false) -> void:
	_composer_state_updates_suspended = true
	_input.text = text
	_input.set_caret_line(maxi(_input.get_line_count() - 1, 0))
	_input.set_caret_column(
		_input.get_line(_input.get_caret_line()).length()
	)
	_composer_state_updates_suspended = false
	if not preserve_history_cursor:
		_prompt_history_cursor = -1
		_prompt_history_draft = ""
	_store_current_composer_state_in_memory()
	_update_composer_actions()
	if is_instance_valid(_composer_save_timer):
		_composer_save_timer.start()


func _prompt_history() -> Array:
	var state_key := _current_composer_state_key()
	var value: Variant = _prompt_history_by_thread.get(state_key, [])
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


func _record_prompt_history(prompt: String) -> void:
	var cleaned := _strip_legacy_editor_context(prompt).strip_edges()
	if cleaned.is_empty():
		return
	var state_key := _current_composer_state_key()
	var history := _prompt_history()
	if history.is_empty() or str(history.back()) != cleaned:
		history.append(cleaned)
	while history.size() > 50:
		history.pop_front()
	_prompt_history_by_thread[state_key] = history
	_prompt_history_cursor = -1
	_prompt_history_draft = ""
	_save_settings()
	_update_composer_actions()


func _navigate_prompt_history(older: bool) -> void:
	var history := _prompt_history()
	if history.is_empty():
		return
	if older:
		if _prompt_history_cursor < 0:
			_prompt_history_draft = _input.text
			_prompt_history_cursor = history.size() - 1
		else:
			_prompt_history_cursor = maxi(_prompt_history_cursor - 1, 0)
	else:
		if _prompt_history_cursor < 0:
			return
		if _prompt_history_cursor < history.size() - 1:
			_prompt_history_cursor += 1
		else:
			_prompt_history_cursor = -1
			_set_composer_text(_prompt_history_draft, true)
			return
	_set_composer_text(
		str(history[_prompt_history_cursor]),
		true
	)


func _populate_prompt_history_menu() -> void:
	var popup := _history_button.get_popup()
	popup.clear()
	_prompt_history_popup_items.clear()
	var history := _prompt_history()
	if history.is_empty():
		popup.add_item("This conversation has no prompt history", 0)
		popup.set_item_disabled(0, true)
		return
	var visible_count := mini(history.size(), 12)
	for reverse_index in range(visible_count):
		var prompt := str(history[history.size() - 1 - reverse_index])
		_prompt_history_popup_items.append(prompt)
		popup.add_item(_single_line_preview(prompt, 72), reverse_index)
		popup.set_item_tooltip(reverse_index, prompt)


func _on_prompt_history_selected(item_id: int) -> void:
	if item_id < 0 or item_id >= _prompt_history_popup_items.size():
		return
	_set_composer_text(_prompt_history_popup_items[item_id])
	_input.grab_focus()


func _small_queue_action_button(
	symbol: String,
	tooltip: String,
	callback: Callable
) -> Button:
	var button := Button.new()
	button.text = symbol
	button.flat = true
	button.custom_minimum_size = Vector2(24.0, 24.0)
	button.tooltip_text = tooltip
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(callback)
	return button


func _render_followup_queue() -> void:
	if not is_instance_valid(_followup_queue_panel):
		return
	for child in _followup_queue_items.get_children():
		_followup_queue_items.remove_child(child)
		child.queue_free()
	_followup_queue_panel.visible = not _followup_queue.is_empty()
	if _followup_queue.is_empty():
		return
	_followup_queue_title.text = "Queued · %d" % _followup_queue.size()
	_followup_queue_scroll.custom_minimum_size = Vector2(
		0.0,
		float(mini(_followup_queue.size(), 3) * 32)
	)

	for item_index in range(_followup_queue.size()):
		var item: Dictionary = _followup_queue[item_index]
		var item_panel := PanelContainer.new()
		var item_style := StyleBoxFlat.new()
		item_style.bg_color = Color(0.13, 0.15, 0.19, 0.92)
		item_style.corner_radius_top_left = 5
		item_style.corner_radius_top_right = 5
		item_style.corner_radius_bottom_left = 5
		item_style.corner_radius_bottom_right = 5
		item_style.content_margin_left = 6.0
		item_style.content_margin_top = 3.0
		item_style.content_margin_right = 3.0
		item_style.content_margin_bottom = 3.0
		item_panel.add_theme_stylebox_override("panel", item_style)
		_followup_queue_items.add_child(item_panel)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		item_panel.add_child(row)

		var number_label := Label.new()
		number_label.text = str(item_index + 1)
		number_label.custom_minimum_size = Vector2(18.0, 0.0)
		number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number_label.add_theme_font_size_override("font_size", 11)
		number_label.add_theme_color_override(
			"font_color",
			Color(0.48, 0.68, 0.96)
		)
		row.add_child(number_label)

		var prompt_label := Label.new()
		prompt_label.text = _single_line_preview(
			str(item.get("prompt", "")),
			100
		)
		prompt_label.tooltip_text = str(item.get("prompt", ""))
		prompt_label.clip_text = true
		prompt_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prompt_label.add_theme_font_size_override("font_size", 12)
		row.add_child(prompt_label)

		var move_up := _small_queue_action_button(
			"↑",
			"Move earlier",
			Callable(self, "_move_followup_queue_item").bind(item_index, -1)
		)
		move_up.disabled = item_index == 0
		row.add_child(move_up)
		var move_down := _small_queue_action_button(
			"↓",
			"Move later",
			Callable(self, "_move_followup_queue_item").bind(item_index, 1)
		)
		move_down.disabled = item_index == _followup_queue.size() - 1
		row.add_child(move_down)
		row.add_child(
			_small_queue_action_button(
				"✎",
				"Edit in composer",
				Callable(self, "_edit_followup_queue_item").bind(item_index)
			)
		)
		row.add_child(
			_small_queue_action_button(
				"▶",
				"Send now (appends to the current turn while Godex is working)",
				Callable(self, "_send_followup_queue_item_now").bind(item_index)
			)
		)
		row.add_child(
			_small_queue_action_button(
				"×",
				"Remove from queue",
				Callable(self, "_delete_followup_queue_item").bind(item_index)
			)
		)


func _followup_queue_changed() -> void:
	_store_current_composer_state_in_memory()
	_render_followup_queue()
	_save_settings()
	_update_composer_actions()


func _queue_current_input() -> void:
	if _state != ConnectionState.TURN_RUNNING or _turn_id.is_empty():
		_send_current_input()
		return
	var prompt := _input.text.strip_edges()
	if prompt.is_empty():
		return
	var skill := _attached_skill.duplicate(true)
	_set_composer_text("")
	_clear_pending_skill()
	_enqueue_followup_prompt(prompt, skill)


func _enqueue_followup_prompt(
	prompt: String,
	skill: Dictionary = {}
) -> void:
	var cleaned_prompt := prompt.strip_edges()
	if cleaned_prompt.is_empty():
		return
	_followup_queue.append(
		{
			"prompt": cleaned_prompt,
			"skill": skill.duplicate(true),
		}
	)
	_followup_queue_changed()


func _move_followup_queue_item(item_index: int, direction: int) -> void:
	var target_index := item_index + direction
	if (
		item_index < 0
		or item_index >= _followup_queue.size()
		or target_index < 0
		or target_index >= _followup_queue.size()
	):
		return
	var item: Dictionary = _followup_queue[item_index]
	_followup_queue.remove_at(item_index)
	_followup_queue.insert(target_index, item)
	_followup_queue_changed()


func _edit_followup_queue_item(item_index: int) -> void:
	if item_index < 0 or item_index >= _followup_queue.size():
		return
	var queued_item: Dictionary = _followup_queue[item_index]
	var current_draft := _input.text.strip_edges()
	if current_draft.is_empty():
		_followup_queue.remove_at(item_index)
	else:
		_followup_queue[item_index] = {
			"prompt": current_draft,
			"skill": _attached_skill.duplicate(true),
		}
	_attached_skill = (
		(queued_item.get("skill", {}) as Dictionary).duplicate(true)
		if typeof(queued_item.get("skill", {})) == TYPE_DICTIONARY
		else {}
	)
	_update_skill_selector_presentation()
	_set_composer_text(str(queued_item.get("prompt", "")))
	_followup_queue_changed()
	_input.grab_focus()


func _delete_followup_queue_item(item_index: int) -> void:
	if item_index < 0 or item_index >= _followup_queue.size():
		return
	_followup_queue.remove_at(item_index)
	_followup_queue_changed()


func _send_followup_queue_item_now(item_index: int) -> void:
	if item_index < 0 or item_index >= _followup_queue.size():
		return
	var queued_item: Dictionary = _followup_queue[item_index]
	_followup_queue.remove_at(item_index)
	_followup_queue_changed()
	var skill: Dictionary = queued_item.get("skill", {}) as Dictionary
	var prompt := str(queued_item.get("prompt", ""))
	if _state == ConnectionState.TURN_RUNNING and not _turn_id.is_empty():
		_send_steer(prompt, skill)
	elif _state == ConnectionState.READY:
		_send_prompt(prompt, skill)
	else:
		_enqueue_followup_prompt(prompt, skill)


func _flush_followup_queue() -> void:
	if _state != ConnectionState.READY or _followup_queue.is_empty():
		return
	var queued_item: Dictionary = _followup_queue.pop_front()
	_followup_queue_changed()
	var skill: Dictionary = queued_item.get("skill", {}) as Dictionary
	_send_prompt(str(queued_item.get("prompt", "")), skill)


func _update_composer_actions() -> void:
	if not is_instance_valid(_input):
		return
	var has_text := not _input.text.strip_edges().is_empty()
	var running := _state == ConnectionState.TURN_RUNNING
	_input.placeholder_text = (
		"Queue for the next turn… (Enter to queue, Shift/Ctrl+Enter for a newline)"
		if running
		else "Ask Godex… (Enter to send, Shift/Ctrl+Enter for a newline)"
	)
	if is_instance_valid(_queue_button):
		_queue_button.visible = running
		_queue_button.disabled = not has_text or _show_archived_threads
	if is_instance_valid(_send_button):
		_send_button.visible = true
		_send_button.disabled = not has_text or _show_archived_threads
		_send_button.tooltip_text = (
			"Queue for the next turn (Enter)"
			if running
			else "Send message (Enter)"
		)
	if is_instance_valid(_history_button):
		var history_count := _prompt_history().size()
		_history_button.tooltip_text = (
			"Prompt history · %d items (Alt+↑ / Alt+↓)" % history_count
			if history_count > 0
			else "Prompt history (Alt+↑ / Alt+↓)"
		)


func _send_current_input() -> void:
	var prompt := _input.text.strip_edges()
	if prompt.is_empty():
		return
	var attached_skill := _attached_skill.duplicate(true)
	_set_composer_text("")
	_clear_pending_skill()
	_queue_or_send_prompt(prompt, attached_skill)


func _queue_or_send_prompt(
	prompt: String,
	skill: Dictionary = {}
) -> void:
	var queued_prompt := {
		"prompt": prompt,
		"skill": skill,
	}
	if _process_id < 0 or _state == ConnectionState.ERROR:
		_pending_prompts.append(queued_prompt)
		_connect_server()
		return

	if _thread_id.is_empty():
		_pending_prompts.append(queued_prompt)
		return

	if _state == ConnectionState.TURN_RUNNING and not _turn_id.is_empty():
		_enqueue_followup_prompt(prompt, skill)
		return

	if _state != ConnectionState.READY:
		_pending_prompts.append(queued_prompt)
		return

	_send_prompt(prompt, skill)


func _send_steer(
	prompt: String,
	skill: Dictionary = {}
) -> void:
	_record_prompt_history(prompt)
	_append_user_message(_strip_legacy_editor_context(prompt))
	_send_request(
		"turn/steer",
		{
			"threadId": _thread_id,
			"expectedTurnId": _turn_id,
			"input": _build_turn_input(prompt, skill),
		}
	)


func _send_prompt(
	prompt: String,
	skill: Dictionary = {}
) -> void:
	_record_prompt_history(prompt)
	_append_user_message(_strip_legacy_editor_context(prompt))
	_assistant_received_text = false
	_assistant_stream_text = ""
	_clear_current_diff()
	_set_state(ConnectionState.TURN_RUNNING, "Sending…")
	var turn_params: Dictionary = {
		"threadId": _thread_id,
		"input": _build_turn_input(prompt, skill),
	}
	var model_id := _selected_model()
	if not model_id.is_empty():
		turn_params["model"] = model_id
	var reasoning_effort := _selected_effort()
	if not reasoning_effort.is_empty():
		turn_params["effort"] = reasoning_effort
	_send_request("turn/start", turn_params)


func _build_turn_input(
	prompt: String,
	skill: Dictionary = {}
) -> Array:
	var turn_input: Array = [{"type": "text", "text": prompt}]
	if not skill.is_empty():
		turn_input.append(
			{
				"type": "skill",
				"name": str(skill.get("name", "")),
				"path": str(skill.get("path", "")),
			}
		)
	return turn_input


func _flush_pending_prompt() -> void:
	if _state != ConnectionState.READY or _pending_prompts.is_empty():
		return
	var queued_prompt: Dictionary = _pending_prompts.pop_front()
	var skill: Dictionary = queued_prompt.get("skill", {}) as Dictionary
	_send_prompt(str(queued_prompt.get("prompt", "")), skill)


func _send_request(method: String, params: Variant = null) -> int:
	var request_id := _next_request_id
	_next_request_id += 1
	_requests[request_id] = method
	var message := {
		"id": request_id,
		"method": method,
	}
	if params != null:
		message["params"] = params
	_send_message(message)
	return request_id


func _send_notification(method: String, params: Dictionary) -> void:
	_send_message({"method": method, "params": params})


func _send_message(message: Dictionary) -> void:
	if _stdio == null or not _stdio.is_open():
		_append_error("The Codex communication pipe is not connected.")
		return
	var bytes := (JSON.stringify(message) + "\n").to_utf8_buffer()
	_stdio.store_buffer(bytes)
	_stdio.flush()


func _handle_server_request(message: Dictionary) -> void:
	var method := str(message.get("method", ""))
	var request_id: Variant = message.get("id")
	var supported_methods := [
		"item/commandExecution/requestApproval",
		"item/fileChange/requestApproval",
		"item/permissions/requestApproval",
		"item/tool/requestUserInput",
	]
	if method not in supported_methods:
		_send_message(
			{
				"id": request_id,
				"error": {
					"code": -32601,
					"message": "Godex does not currently support this interaction request: %s" % method,
				}
			}
		)
		return

	_server_request_queue.append(
		{
			"id": request_id,
			"method": method,
			"params": message.get("params", {}),
		}
	)
	_show_next_server_request()


func _show_next_server_request() -> void:
	if not _active_server_request.is_empty() or _server_request_queue.is_empty():
		return
	_active_server_request = _server_request_queue.pop_front()
	var method := str(_active_server_request.get("method", ""))
	if method == "item/tool/requestUserInput":
		_show_question_request()
	else:
		_show_approval_request()


func _show_approval_request() -> void:
	var method := str(_active_server_request.get("method", ""))
	var params: Dictionary = _active_server_request.get("params", {}) as Dictionary
	var title := "Godex permission request"
	var details := PackedStringArray()

	match method:
		"item/commandExecution/requestApproval":
			title = "Allow Godex to run a command?"
			details.append("Command:\n%s" % str(params.get("command", "Not provided")))
			details.append("Working directory: %s" % str(params.get("cwd", _project_cwd())))
		"item/fileChange/requestApproval":
			title = "Allow Godex to modify files?"
			var grant_root := str(params.get("grantRoot", ""))
			if grant_root.is_empty():
				grant_root = "Files involved in the current request"
			details.append("Authorized scope: %s" % grant_root)
		"item/permissions/requestApproval":
			title = "Allow Godex to extend permissions?"
			details.append(
				"Requested permissions:\n%s"
				% JSON.stringify(params.get("permissions", {}), "\t")
			)
			details.append("Working directory: %s" % str(params.get("cwd", _project_cwd())))

	var reason := str(params.get("reason", "")).strip_edges()
	if not reason.is_empty():
		details.append("Reason: %s" % reason)
	details.append(
		"Review the request and its scope. Allow once applies only to the current turn; "
		+ "Allow for this session lasts until the current Godex connection ends."
	)

	_approval_dialog.title = title
	_approval_details.text = "\n\n".join(details)
	_approval_details.set_caret_line(0)
	_approval_details.set_caret_column(0)
	_approval_session_button.visible = true
	_approval_cancel_turn_button.visible = method != "item/permissions/requestApproval"
	if DisplayServer.get_name() != "headless":
		_approval_dialog.popup_centered(Vector2i(680, 430))


func _approve_active_request_once() -> void:
	_approve_active_request("turn")


func _on_approval_custom_action(action: StringName) -> void:
	if action == &"accept_session":
		_approve_active_request("session")
	elif action == &"cancel_turn":
		_cancel_active_request()


func _approve_active_request(scope: String) -> void:
	if _active_server_request.is_empty():
		return
	var method := str(_active_server_request.get("method", ""))
	var params: Dictionary = _active_server_request.get("params", {}) as Dictionary
	var result: Dictionary
	if method == "item/permissions/requestApproval":
		result = {
			"permissions": params.get("permissions", {}),
			"scope": scope,
		}
	else:
		result = {
			"decision": "acceptForSession" if scope == "session" else "accept",
		}
	_resolve_active_server_request(result, "Allowed Godex to perform the request")


func _decline_active_request() -> void:
	if _active_server_request.is_empty():
		return
	var method := str(_active_server_request.get("method", ""))
	if method == "item/tool/requestUserInput":
		_cancel_question_answers()
		return
	var result := (
		{"permissions": {}, "scope": "turn"}
		if method == "item/permissions/requestApproval"
		else {"decision": "decline"}
	)
	_resolve_active_server_request(result, "Declined the Godex permission request")


func _cancel_active_request() -> void:
	if _active_server_request.is_empty():
		return
	var params: Dictionary = _active_server_request.get("params", {}) as Dictionary
	_resolve_active_server_request({"decision": "cancel"}, "Declined the request and stopped the related operation")
	var request_turn_id := str(params.get("turnId", ""))
	if not _thread_id.is_empty() and not request_turn_id.is_empty():
		_send_request(
			"turn/interrupt",
			{"threadId": _thread_id, "turnId": request_turn_id}
		)


func _show_question_request() -> void:
	for child in _question_container.get_children():
		child.queue_free()
	_question_fields.clear()

	var params: Dictionary = _active_server_request.get("params", {}) as Dictionary
	var questions_value: Variant = params.get("questions", [])
	if typeof(questions_value) != TYPE_ARRAY:
		_cancel_question_answers()
		return

	for question_value in questions_value as Array:
		if typeof(question_value) != TYPE_DICTIONARY:
			continue
		var question: Dictionary = question_value as Dictionary

		var header := Label.new()
		header.text = str(question.get("header", "Godex question"))
		header.add_theme_font_size_override("font_size", 16)
		_question_container.add_child(header)

		var prompt_label := Label.new()
		prompt_label.text = str(question.get("question", ""))
		prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_question_container.add_child(prompt_label)

		var selector := OptionButton.new()
		selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var options_value: Variant = question.get("options", [])
		if typeof(options_value) == TYPE_ARRAY:
			for option_value in options_value as Array:
				if typeof(option_value) != TYPE_DICTIONARY:
					continue
				var option: Dictionary = option_value as Dictionary
				var label := str(option.get("label", ""))
				var description := str(option.get("description", ""))
				selector.add_item(
					label if description.is_empty() else "%s — %s" % [label, description]
				)
				selector.set_item_metadata(selector.get_item_count() - 1, label)
		selector.visible = selector.get_item_count() > 0
		_question_container.add_child(selector)

		var custom_answer := LineEdit.new()
		custom_answer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		custom_answer.secret = bool(question.get("isSecret", false))
		custom_answer.placeholder_text = (
			"Custom answer (leave blank to use the option above)"
			if selector.visible
			else "Enter an answer"
		)
		_question_container.add_child(custom_answer)

		_question_fields.append(
			{
				"id": str(question.get("id", "")),
				"selector": selector,
				"custom": custom_answer,
			}
		)

	if _question_fields.is_empty():
		_cancel_question_answers()
		return

	if DisplayServer.get_name() != "headless":
		_question_dialog.popup_centered(Vector2i(680, 500))
	var auto_resolution_value: Variant = params.get("autoResolutionMs")
	if auto_resolution_value != null:
		var auto_resolution_seconds := float(auto_resolution_value) / 1000.0
		if auto_resolution_seconds > 0.0:
			_request_auto_timer.start(maxf(0.1, auto_resolution_seconds))


func _submit_question_answers() -> void:
	if _active_server_request.is_empty():
		return
	var answers: Dictionary = {}
	for field in _question_fields:
		var question_id := str(field.get("id", ""))
		if question_id.is_empty():
			continue
		var custom_answer := field.get("custom") as LineEdit
		var selector := field.get("selector") as OptionButton
		var answer := custom_answer.text.strip_edges()
		if answer.is_empty() and selector != null and selector.get_item_count() > 0:
			answer = str(selector.get_item_metadata(selector.selected))
		answers[question_id] = {
			"answers": [] if answer.is_empty() else [answer],
		}
	_resolve_active_server_request({"answers": answers}, "Submitted the answer to Godex")


func _cancel_question_answers() -> void:
	if _active_server_request.is_empty():
		return
	_resolve_active_server_request(
		{"answers": _empty_question_answers()},
		"Canceled the Godex question"
	)


func _empty_question_answers() -> Dictionary:
	var answers: Dictionary = {}
	for field in _question_fields:
		var question_id := str(field.get("id", ""))
		if not question_id.is_empty():
			answers[question_id] = {"answers": []}
	return answers


func _auto_resolve_question_request() -> void:
	if (
		not _active_server_request.is_empty()
		and str(_active_server_request.get("method", "")) == "item/tool/requestUserInput"
	):
		_resolve_active_server_request(
			{"answers": _empty_question_answers()},
			"The Godex question was skipped automatically after timing out"
		)


func _resolve_active_server_request(result: Dictionary, activity: String) -> void:
	if _active_server_request.is_empty():
		return
	var request_id: Variant = _active_server_request.get("id")
	_active_server_request.clear()
	_question_fields.clear()
	_request_auto_timer.stop()
	_approval_dialog.hide()
	_question_dialog.hide()
	_send_message({"id": request_id, "result": result})
	_append_activity(activity)
	call_deferred("_show_next_server_request")


func _handle_server_request_resolved(request_id: Variant) -> void:
	var normalized_id := str(request_id)
	if (
		not _active_server_request.is_empty()
		and str(_active_server_request.get("id")) == normalized_id
	):
		_active_server_request.clear()
		_question_fields.clear()
		_request_auto_timer.stop()
		_approval_dialog.hide()
		_question_dialog.hide()
		call_deferred("_show_next_server_request")
		return

	for index in range(_server_request_queue.size() - 1, -1, -1):
		if str(_server_request_queue[index].get("id")) == normalized_id:
			_server_request_queue.remove_at(index)


func _rpc_error_message(error_value: Variant) -> String:
	if typeof(error_value) == TYPE_DICTIONARY:
		var error: Dictionary = error_value as Dictionary
		return str(error.get("message", error))
	return str(error_value)


func _request_display_name(method: String) -> String:
	match method:
		"initialize":
			return "Initialize Codex App Server"
		"model/list":
			return "Synchronize model list"
		"skills/list":
			return "Synchronize Skills"
		"thread/list":
			return "Read conversation list"
		"thread/start":
			return "Create conversation"
		"thread/resume":
			return "Resume conversation"
		"thread/read":
			return "Read conversation"
		"turn/start":
			return "Send message"
		"turn/steer":
			return "Append message"
		"turn/interrupt":
			return "Stop response"
		"review/start":
			return "Start code review"
		"thread/compact/start":
			return "Compact conversation"
		_:
			return method if not method.is_empty() else "Codex protocol request"


func _describe_rpc_error(method: String, error_value: Variant) -> String:
	var message := _rpc_error_message(error_value)
	if method == "thread/resume" and "already has an active writer" in message.to_lower():
		return message + "\nThis conversation is already open in another Codex client."
	var code := 0
	if typeof(error_value) == TYPE_DICTIONARY:
		code = int((error_value as Dictionary).get("code", 0))
	var suggestion := ""
	match code:
		-32700:
			suggestion = "Codex could not parse the plugin request. Update Codex or the plugin."
		-32600:
			suggestion = "Codex rejected the request format. The protocol versions may differ."
		-32601:
			suggestion = (
				"The current Codex App Server does not support `%s`; update the local Codex installation."
				% method
			)
		-32602:
			suggestion = (
				"The parameter format for `%s` has changed; update Godex or Codex."
				% method
			)
		-32603:
			suggestion = "The Codex App Server returned an internal error. Try reconnecting."
	if suggestion.is_empty():
		var lower_message := message.to_lower()
		if "unknown method" in lower_message or "not found" in lower_message:
			suggestion = "The current Codex version may not support this feature. Update Codex."
		elif "invalid" in lower_message and "param" in lower_message:
			suggestion = "The plugin and Codex parameter protocols may differ. Update both."
	if suggestion.is_empty():
		return message
	return "%s\nSuggestion: %s" % [message, suggestion]


func _on_new_thread_pressed() -> void:
	if _state == ConnectionState.TURN_RUNNING:
		_append_activity("Stop the current turn before creating a new conversation")
		return

	_store_current_composer_state_in_memory()
	_save_settings()
	_drafts_by_thread.erase("__new__")
	_followup_queues_by_thread.erase("__new__")
	_load_composer_state("")
	_show_archived_threads = false
	_pending_resume_thread_id = ""
	_clear_transcript()
	_append_system_message("Creating a new Godex conversation…")
	if _process_id < 0:
		_create_new_after_connect = true
		_connect_server()
	else:
		_start_thread()


func _on_thread_selected(_index: int) -> void:
	if _updating_thread_selector:
		return

	var selected_thread_id := _selected_thread_id()
	if selected_thread_id.is_empty() or selected_thread_id == _thread_id:
		return

	if _state in [
		ConnectionState.STARTING,
		ConnectionState.STARTING_THREAD,
		ConnectionState.TURN_RUNNING,
	]:
		_select_thread_by_id(_thread_id)
		_append_activity("Wait for the current operation to finish before switching conversations")
		return

	_clear_transcript()
	if _show_archived_threads:
		_thread_id = selected_thread_id
		_append_system_message("Reading archived conversations…")
		_set_state(ConnectionState.STARTING_THREAD, "Reading archived conversations…")
		_send_request(
			"thread/read",
			{"threadId": selected_thread_id, "includeTurns": true}
		)
	else:
		_append_system_message("Restoring the selected conversation…")
		_resume_thread(selected_thread_id)


func _on_archived_threads_toggled(enabled: bool) -> void:
	if _state == ConnectionState.TURN_RUNNING:
		_append_activity("Stop the current turn before switching the archive view")
		return
	_switch_composer_state("")
	_show_archived_threads = enabled
	_thread_id = ""
	_turn_id = ""
	_clear_transcript()
	_append_system_message("Loading archive…" if enabled else "Returning to active conversations…")
	_load_thread_list()


func _update_thread_actions_menu() -> void:
	var popup := _thread_actions_button.get_popup()
	var selected_thread_id := _selected_thread_id()
	var has_selection := not selected_thread_id.is_empty()
	var rename_index := popup.get_item_index(ThreadAction.RENAME)
	var fork_index := popup.get_item_index(ThreadAction.FORK)
	var archive_index := popup.get_item_index(ThreadAction.ARCHIVE_OR_RESTORE)
	var archived_box_index := popup.get_item_index(ThreadAction.TOGGLE_ARCHIVED)
	popup.set_item_disabled(rename_index, not has_selection)
	popup.set_item_disabled(fork_index, not has_selection or _show_archived_threads)
	popup.set_item_disabled(archive_index, not has_selection)
	popup.set_item_text(
		archive_index,
		"Restore" if _show_archived_threads else "Archive"
	)
	popup.set_item_text(
		archived_box_index,
		"Return to active conversations" if _show_archived_threads else "View archive"
	)


func _on_thread_action_selected(action_id: int) -> void:
	if _state in [
		ConnectionState.STARTING,
		ConnectionState.STARTING_THREAD,
		ConnectionState.TURN_RUNNING,
	]:
		return
	if action_id == ThreadAction.TOGGLE_ARCHIVED:
		_on_archived_threads_toggled(not _show_archived_threads)
		return
	var selected_thread_id := _selected_thread_id()
	if selected_thread_id.is_empty():
		return
	match action_id:
		ThreadAction.RENAME:
			_open_rename_thread_dialog(selected_thread_id)
		ThreadAction.FORK:
			_fork_selected_thread(selected_thread_id)
		ThreadAction.ARCHIVE_OR_RESTORE:
			if _show_archived_threads:
				_unarchive_selected_thread(selected_thread_id)
			else:
				_archive_selected_thread(selected_thread_id)


func _open_rename_thread_dialog(thread_id: String) -> void:
	_pending_rename_thread_id = thread_id
	var current_title := ""
	var selected_index := _thread_selector.selected
	if selected_index >= 0 and selected_index < _thread_selector.get_item_count():
		current_title = _thread_selector.get_item_text(selected_index)
	_rename_thread_edit.text = current_title
	_rename_thread_edit.select_all()
	if DisplayServer.get_name() != "headless":
		_rename_thread_dialog.popup_centered(Vector2i(500, 150))
		_rename_thread_edit.grab_focus()


func _on_rename_thread_submitted(_new_text: String) -> void:
	_rename_thread_dialog.hide()
	_confirm_rename_thread()


func _confirm_rename_thread() -> void:
	var new_title := _rename_thread_edit.text.strip_edges()
	if _pending_rename_thread_id.is_empty() or new_title.is_empty():
		_cancel_rename_thread()
		return
	_pending_rename_title = new_title
	_set_state(ConnectionState.STARTING_THREAD, "Renaming conversation…")
	_send_request(
		"thread/name/set",
		{
			"threadId": _pending_rename_thread_id,
			"name": new_title,
		}
	)


func _cancel_rename_thread() -> void:
	_pending_rename_thread_id = ""
	_pending_rename_title = ""


func _fork_selected_thread(thread_id: String) -> void:
	var sandbox_mode := "workspace-write" if _allow_edits_check.button_pressed else "read-only"
	var fork_params: Dictionary = {
		"threadId": thread_id,
		"cwd": _project_cwd(),
		"sandbox": sandbox_mode,
		"approvalPolicy": "on-request",
		"ephemeral": false,
	}
	var model_id := _selected_model()
	if not model_id.is_empty():
		fork_params["model"] = model_id
	_set_state(ConnectionState.STARTING_THREAD, "Creating conversation fork…")
	_send_request("thread/fork", fork_params)


func _archive_selected_thread(thread_id: String) -> void:
	_pending_archive_thread_id = thread_id
	_set_state(ConnectionState.STARTING_THREAD, "Archiving conversation…")
	_send_request("thread/archive", {"threadId": thread_id})


func _unarchive_selected_thread(thread_id: String) -> void:
	_pending_unarchive_thread_id = thread_id
	_set_state(ConnectionState.STARTING_THREAD, "Restoring archived conversation…")
	_send_request("thread/unarchive", {"threadId": thread_id})


func _on_delete_thread_pressed() -> void:
	if _state in [
		ConnectionState.STARTING,
		ConnectionState.STARTING_THREAD,
		ConnectionState.TURN_RUNNING,
	]:
		return

	var selected_thread_id := _selected_thread_id()
	if selected_thread_id.is_empty():
		return

	var selected_index := _thread_selector.selected
	var selected_title := "Current conversation"
	if selected_index >= 0 and selected_index < _thread_selector.get_item_count():
		selected_title = _thread_selector.get_item_text(selected_index)

	_pending_delete_thread_id = selected_thread_id
	_pending_delete_thread_title = selected_title
	_delete_confirmation.dialog_text = (
		"Permanently delete conversation \"%s\"?\n\nThis action cannot be undone."
		% selected_title
	)
	_delete_confirmation.popup_centered(Vector2i(460, 190))


func _confirm_delete_thread() -> void:
	if _pending_delete_thread_id.is_empty():
		return
	if _process_id < 0 or _stdio == null:
		_append_error("Codex is not connected, so the conversation cannot be deleted.")
		_pending_delete_thread_id = ""
		_pending_delete_thread_title = ""
		return

	_set_state(ConnectionState.STARTING_THREAD, "Deleting conversation…")
	_send_request("thread/delete", {"threadId": _pending_delete_thread_id})


func _cancel_delete_thread() -> void:
	_pending_delete_thread_id = ""
	_pending_delete_thread_title = ""


func _handle_thread_delete_response() -> void:
	var deleted_thread_id := _pending_delete_thread_id
	var deleted_thread_title := _pending_delete_thread_title
	_pending_delete_thread_id = ""
	_pending_delete_thread_title = ""
	if deleted_thread_id.is_empty():
		_set_state(ConnectionState.READY, "Connected")
		return

	var deleted_current_thread := deleted_thread_id == _thread_id
	_remove_composer_state(deleted_thread_id)
	if deleted_current_thread:
		_thread_id = ""
		_turn_id = ""
		_clear_transcript()
		_append_system_message("Conversation \"%s\" was permanently deleted." % deleted_thread_title)
	_remove_thread_option(deleted_thread_id)
	if deleted_current_thread:
		_load_thread_list()
	else:
		_set_state(ConnectionState.READY, "Connected")


func _handle_thread_deleted_notification(thread_id: String) -> void:
	if thread_id.is_empty() or thread_id == _pending_delete_thread_id:
		return

	var deleted_current_thread := thread_id == _thread_id
	_remove_composer_state(thread_id)
	if deleted_current_thread:
		_thread_id = ""
		_turn_id = ""
		_clear_transcript()
		_append_system_message("The current conversation was deleted; loading another conversation…")
	_remove_thread_option(thread_id)
	if deleted_current_thread:
		_load_thread_list()


func _handle_thread_archived_notification(thread_id: String) -> void:
	if thread_id.is_empty() or thread_id == _pending_archive_thread_id:
		return
	if _show_archived_threads:
		_load_thread_list()
		return
	var archived_current_thread := thread_id == _thread_id
	if archived_current_thread:
		_switch_composer_state("")
		_thread_id = ""
		_turn_id = ""
		_clear_transcript()
		_append_system_message("The current conversation was archived; loading another conversation…")
	_remove_thread_option(thread_id)
	if archived_current_thread:
		_load_thread_list()


func _on_reconnect_pressed() -> void:
	_connect_server()


func _on_executable_path_submitted(_new_text: String) -> void:
	_save_settings()
	_connect_server()


func _on_model_selected(index: int) -> void:
	if _updating_model_selector:
		return
	if index < 0 or index >= _model_selector.get_item_count():
		return

	_selected_model_id = str(_model_selector.get_item_metadata(index))
	_update_model_selector_presentation()
	_update_effort_options()
	_save_settings()
	if _selected_model_id.is_empty():
		_append_activity("Now following the current Codex configuration; applies to the next message")
	else:
		_append_activity(
			"Selected model %s; applies to the next message"
			% _selected_model_id
		)


func _on_effort_selected(index: int) -> void:
	if _updating_effort_selector:
		return
	if index < 0 or index >= _effort_selector.get_item_count():
		return
	_selected_reasoning_effort = str(_effort_selector.get_item_metadata(index))
	_update_effort_selector_presentation()
	_save_settings()
	if _selected_reasoning_effort.is_empty():
		_append_activity("Reasoning effort now follows the Codex configuration")
	else:
		_append_activity(
			"The next message will use %s reasoning effort"
			% _selected_reasoning_effort
		)


func _on_refresh_models_pressed() -> void:
	if _process_id < 0:
		_connect_server()
		return
	_load_model_list(false)


func _on_allow_edits_toggled(_enabled: bool) -> void:
	_save_settings()
	_update_policy_label()
	if not _thread_id.is_empty():
		_append_activity("The permission mode applies to the next new conversation")


func _on_interrupt_pressed() -> void:
	if _thread_id.is_empty() or _turn_id.is_empty():
		return
	_send_request(
		"turn/interrupt",
		{"threadId": _thread_id, "turnId": _turn_id}
	)


func _on_input_gui_input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var key_event := event as InputEventKey
	if (
		key_event.pressed
		and not key_event.echo
		and key_event.ctrl_pressed
		and key_event.keycode == KEY_F
	):
		_open_search()
		accept_event()
		return
	if (
		key_event.pressed
		and not key_event.echo
		and key_event.alt_pressed
		and key_event.keycode in [KEY_UP, KEY_DOWN]
	):
		_navigate_prompt_history(key_event.keycode == KEY_UP)
		accept_event()
		return
	if (
		key_event.pressed
		and not key_event.echo
		and key_event.keycode in [KEY_ENTER, KEY_KP_ENTER]
	):
		if (
			key_event.ctrl_pressed
			and key_event.shift_pressed
			and _state == ConnectionState.TURN_RUNNING
		):
			_queue_current_input()
			accept_event()
			return
		if key_event.shift_pressed or key_event.ctrl_pressed:
			_input.insert_text_at_caret("\n")
			accept_event()
			return
		_send_current_input()
		accept_event()


func _shortcut_input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var key_event := event as InputEventKey
	if (
		key_event.pressed
		and not key_event.echo
		and key_event.ctrl_pressed
		and key_event.keycode == KEY_F
	):
		_open_search()
		get_viewport().set_input_as_handled()


func _open_search() -> void:
	if not is_instance_valid(_search_panel):
		return
	_search_panel.visible = true
	_layout_search_panel()
	_search_edit.grab_focus()
	_search_edit.select_all()
	_refresh_search_matches()


func _close_search() -> void:
	if not is_instance_valid(_search_panel):
		return
	_search_panel.visible = false
	_search_match_rounds.clear()
	_search_match_index = -1
	_sync_round_history_search()
	if is_instance_valid(_transcript):
		_transcript.grab_focus()


func _on_search_gui_input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ESCAPE:
		_close_search()
		accept_event()
	elif key_event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		if key_event.shift_pressed:
			_previous_search_match()
		else:
			_next_search_match()
		accept_event()


func _on_search_text_changed(_text: String) -> void:
	_refresh_search_matches()


func _conversation_search_corpora() -> PackedStringArray:
	var corpora := PackedStringArray()
	var current_round := -1
	for entry in _transcript_entries:
		var kind := str(entry.get("kind", ""))
		if kind == "user":
			current_round += 1
			corpora.append(str(entry.get("text", "")))
			continue
		if current_round < 0:
			continue
		var searchable := ""
		match kind:
			"assistant", "system", "activity", "error":
				searchable = str(entry.get("text", ""))
			"tool":
				searchable = "\n".join(
					[
						str(entry.get("title", "")),
						str(entry.get("summary", "")),
						str(entry.get("details", "")),
					]
				)
		if not searchable.is_empty():
			corpora[current_round] += "\n" + searchable
	if current_round >= 0 and not _assistant_stream_text.is_empty():
		corpora[current_round] += "\n" + _assistant_stream_text
	return corpora


func _refresh_search_matches(jump_to_match := true) -> void:
	if not is_instance_valid(_search_edit):
		return
	var query := _search_edit.text.strip_edges().to_lower()
	var previous_round := -1
	if (
		_search_match_index >= 0
		and _search_match_index < _search_match_rounds.size()
	):
		previous_round = _search_match_rounds[_search_match_index]
	_search_match_rounds.clear()
	if not query.is_empty():
		var corpora := _conversation_search_corpora()
		for round_index in range(corpora.size()):
			if corpora[round_index].to_lower().contains(query):
				_search_match_rounds.append(round_index)
	_search_match_index = -1
	if not _search_match_rounds.is_empty():
		var previous_index := _search_match_rounds.find(previous_round)
		_search_match_index = previous_index if previous_index >= 0 else 0
	_update_search_count()
	_sync_round_history_search()
	if jump_to_match and _search_match_index >= 0:
		_jump_to_search_match()


func _update_search_count() -> void:
	if not is_instance_valid(_search_count_label):
		return
	var current := _search_match_index + 1 if _search_match_index >= 0 else 0
	_search_count_label.text = "%d / %d" % [
		current,
		_search_match_rounds.size(),
	]


func _next_search_match() -> void:
	if _search_match_rounds.is_empty():
		return
	_search_match_index = posmod(
		_search_match_index + 1,
		_search_match_rounds.size()
	)
	_update_search_count()
	_sync_round_history_search()
	_jump_to_search_match()


func _previous_search_match() -> void:
	if _search_match_rounds.is_empty():
		return
	_search_match_index = posmod(
		_search_match_index - 1,
		_search_match_rounds.size()
	)
	_update_search_count()
	_sync_round_history_search()
	_jump_to_search_match()


func _jump_to_search_match() -> void:
	if (
		_search_match_index < 0
		or _search_match_index >= _search_match_rounds.size()
	):
		return
	var round_index := _search_match_rounds[_search_match_index]
	if round_index < 0 or round_index >= _round_summaries.size():
		return
	_transcript_scroll_tracking_suspended = true
	_transcript.scroll_to_line(
		int(_round_summaries[round_index].get("line", 0))
	)
	_transcript_scroll_tracking_suspended = false
	_transcript_following = false
	_update_latest_button()
	_round_active_index = round_index
	_round_history_rail.call("set_active_round", round_index)


func _sync_round_history_search() -> void:
	if not is_instance_valid(_round_history_rail):
		return
	var active_match_round := -1
	if (
		_search_match_index >= 0
		and _search_match_index < _search_match_rounds.size()
	):
		active_match_round = _search_match_rounds[_search_match_index]
	_round_history_rail.call(
		"set_search_matches",
		_search_match_rounds,
		active_match_round
	)


func _set_state(new_state: ConnectionState, text: String) -> void:
	var previous_state := _state
	_state = new_state
	if previous_state != new_state or (
		is_instance_valid(_status_label) and _status_label.text != text
	):
		_record_connection_event(text)
	if not is_instance_valid(_status_label):
		return

	_status_label.text = text
	match new_state:
		ConnectionState.READY:
			_auto_reconnect_pending = false
			_auto_reconnect_attempt = 0
			_reconnect_restore_thread_id = ""
			_status_dot.modulate = Color(0.31, 0.80, 0.48)
		ConnectionState.TURN_RUNNING, ConnectionState.STARTING, ConnectionState.STARTING_THREAD:
			_status_dot.modulate = Color(0.95, 0.70, 0.25)
		ConnectionState.ERROR:
			_status_dot.modulate = Color(0.94, 0.36, 0.36)
		_:
			_status_dot.modulate = Color(0.55, 0.58, 0.62)

	_reconnect_button.text = "Reconnect" if _process_id >= 0 else "Connect"
	_interrupt_button.disabled = new_state != ConnectionState.TURN_RUNNING
	_interrupt_button.visible = new_state == ConnectionState.TURN_RUNNING
	_send_button.visible = true
	_path_edit.editable = new_state not in [
		ConnectionState.STARTING,
		ConnectionState.STARTING_THREAD,
		ConnectionState.TURN_RUNNING,
	]
	_update_thread_controls()
	_update_composer_actions()


func _update_thread_controls() -> void:
	var busy := _state in [
		ConnectionState.STARTING,
		ConnectionState.STARTING_THREAD,
		ConnectionState.TURN_RUNNING,
	]
	if is_instance_valid(_thread_selector):
		_thread_selector.disabled = busy or _first_thread_id().is_empty()
	if is_instance_valid(_delete_thread_button):
		_delete_thread_button.disabled = busy or _selected_thread_id().is_empty()
	if is_instance_valid(_new_thread_button):
		_new_thread_button.disabled = busy
	if is_instance_valid(_thread_actions_button):
		_thread_actions_button.disabled = busy or _process_id < 0
	if is_instance_valid(_model_selector):
		_model_selector.disabled = (
			busy
			or _model_list_request_pending
			or _process_id < 0
			or _model_selector.get_item_count() == 0
		)
	if is_instance_valid(_refresh_models_button):
		_refresh_models_button.disabled = (
			busy or _model_list_request_pending or _process_id < 0
		)
	if is_instance_valid(_effort_selector):
		_effort_selector.disabled = (
			busy
			or _model_list_request_pending
			or _process_id < 0
			or _effort_selector.get_item_count() == 0
			)
	if is_instance_valid(_skills_selector):
		_skills_selector.disabled = (
			busy
			or _process_id < 0
			or _skills.is_empty()
			or _show_archived_threads
		)
	if is_instance_valid(_refresh_skills_button):
		_refresh_skills_button.disabled = busy or _process_id < 0
	if is_instance_valid(_tools_button):
		_tools_button.disabled = false
	if is_instance_valid(_input):
		_input.editable = not _show_archived_threads
	if is_instance_valid(_history_button):
		_history_button.disabled = _show_archived_threads
	_update_composer_actions()


func _update_policy_label() -> void:
	if _allow_edits_check.button_pressed:
		_policy_label.text = "Project writes only · extra access requires approval"
		_configure_icon_button(
			_allow_edits_check,
			&"Edit",
			"✎",
			"Project edit permission: allow changes to this project\nClick to switch to read-only"
		)
	else:
		_policy_label.text = "Read-only · extra access requires approval"
		_configure_icon_button(
			_allow_edits_check,
			&"Lock",
			"🔒",
			"Project edit permission: read-only\nClick to allow changes to this project"
		)


func _clear_transcript() -> void:
	_transcript_entries.clear()
	_assistant_stream_text = ""
	_tool_entry_by_item_id.clear()
	_image_load_queue.clear()
	_image_load_queued_keys.clear()
	_image_load_scheduled = false
	_image_failed_sources.clear()
	_history_image_sources_on_demand.clear()
	_image_source_by_token.clear()
	_image_token_by_cache_key.clear()
	_next_image_token = 1
	_plan_entries.clear()
	_plan_explanation = ""
	_plan_text = ""
	_plan_stream_text = ""
	_round_summaries.clear()
	_round_active_index = -1
	_round_preview_index = -1
	_search_match_rounds.clear()
	_search_match_index = -1
	_transcript_render_pending = false
	_transcript_render_has_new_content = false
	_transcript_following = true
	_transcript_has_unseen_content = false
	_next_transcript_scroll_restore = -1.0
	_transcript_render_generation += 1
	if is_instance_valid(_transcript):
		_transcript.clear()
	if is_instance_valid(_plan_panel):
		_plan_panel.visible = false
	if is_instance_valid(_round_history_rail):
		_round_history_rail.call(
			"set_rounds",
			_round_summaries,
			-1
		)
		_round_history_rail.call(
			"set_search_matches",
			_search_match_rounds,
			-1
		)
		_round_history_rail.visible = false
	if is_instance_valid(_round_preview):
		_round_preview.visible = false
	if is_instance_valid(_new_content_button):
		_new_content_button.visible = false
	if is_instance_valid(_search_edit) and not _search_edit.text.is_empty():
		_search_edit.clear()


func _request_transcript_render(
	immediate := false,
	new_content := true
) -> void:
	if not is_instance_valid(_transcript):
		return
	_transcript_render_has_new_content = (
		_transcript_render_has_new_content or new_content
	)
	if _transcript_render_suspended:
		_transcript_render_pending = true
		return
	var now := Time.get_ticks_msec()
	if immediate or now - _last_transcript_render_msec >= 33:
		_render_transcript()
	else:
		_transcript_render_pending = true


func _render_transcript() -> void:
	if not is_instance_valid(_transcript):
		return
	var scrollbar := _transcript.get_v_scroll_bar()
	var previous_scroll := (
		_next_transcript_scroll_restore
		if _next_transcript_scroll_restore >= 0.0
		else scrollbar.value
	)
	_next_transcript_scroll_restore = -1.0
	var should_follow := _transcript_following
	var had_new_content := _transcript_render_has_new_content
	_transcript_render_pending = false
	_transcript_render_has_new_content = false
	_last_transcript_render_msec = Time.get_ticks_msec()
	_transcript_render_generation += 1
	var render_generation := _transcript_render_generation
	_transcript_scroll_tracking_suspended = true
	_transcript.clear()
	var round_lines := PackedInt32Array()
	for entry in _transcript_entries:
		if str(entry.get("kind", "")) == "user":
			round_lines.append(maxi(_transcript.get_line_count() - 1, 0))
		_render_transcript_entry(entry)
	if not _assistant_stream_text.is_empty():
		_render_assistant_message(_assistant_stream_text)
	_update_round_history(round_lines)
	_transcript_scroll_tracking_suspended = false
	call_deferred(
		"_restore_transcript_scroll_after_render",
		render_generation,
		previous_scroll,
		should_follow,
		had_new_content
	)


func _restore_transcript_scroll_after_render(
	render_generation: int,
	previous_scroll: float,
	should_follow: bool,
	had_new_content: bool
) -> void:
	if (
		render_generation != _transcript_render_generation
		or not is_instance_valid(_transcript)
	):
		return
	var scrollbar := _transcript.get_v_scroll_bar()
	var scroll_limit := maxf(scrollbar.max_value - scrollbar.page, 0.0)
	_transcript_scroll_tracking_suspended = true
	if should_follow:
		_transcript.scroll_to_line(maxi(_transcript.get_line_count() - 1, 0))
		scrollbar.value = scroll_limit
	else:
		scrollbar.value = clampf(previous_scroll, 0.0, scroll_limit)
	_transcript_scroll_tracking_suspended = false
	_transcript_following = should_follow
	if should_follow:
		_transcript_has_unseen_content = false
	elif had_new_content:
		_transcript_has_unseen_content = true
	_update_latest_button()
	_layout_new_content_button()
	_on_transcript_scroll_changed(scrollbar.value)
	if (
		is_instance_valid(_search_panel)
		and _search_panel.visible
		and not _search_edit.text.strip_edges().is_empty()
	):
		_refresh_search_matches(false)


func _update_latest_button() -> void:
	if not is_instance_valid(_new_content_button):
		return
	_new_content_button.visible = not _transcript_following
	if _transcript_has_unseen_content:
		_new_content_button.text = "↓ New content"
		_new_content_button.tooltip_text = "A new response is available; click to jump to latest"
	else:
		_new_content_button.text = "↓ Jump to latest"
		_new_content_button.tooltip_text = "Jump to the bottom of the conversation"
	if _new_content_button.visible:
		_layout_new_content_button()


func _is_transcript_near_bottom(scroll_value: float) -> bool:
	if not is_instance_valid(_transcript):
		return true
	var scrollbar := _transcript.get_v_scroll_bar()
	var scroll_limit := maxf(scrollbar.max_value - scrollbar.page, 0.0)
	return scroll_limit <= 1.0 or scroll_value >= scroll_limit - 20.0


func _jump_to_latest() -> void:
	if not is_instance_valid(_transcript):
		return
	_transcript_following = true
	_transcript_scroll_tracking_suspended = true
	_transcript.scroll_to_line(maxi(_transcript.get_line_count() - 1, 0))
	var scrollbar := _transcript.get_v_scroll_bar()
	scrollbar.value = maxf(scrollbar.max_value - scrollbar.page, 0.0)
	_transcript_scroll_tracking_suspended = false
	_transcript_has_unseen_content = false
	_update_latest_button()
	_on_transcript_scroll_changed(scrollbar.value)


func _build_round_summaries() -> Array[Dictionary]:
	var rounds: Array[Dictionary] = []
	var current_round := -1
	for entry in _transcript_entries:
		var kind := str(entry.get("kind", ""))
		if kind == "user":
			rounds.append(
				{
					"user": str(entry.get("text", "")),
					"assistant": "",
					"tool_count": 0,
				}
			)
			current_round = rounds.size() - 1
			continue
		if current_round < 0:
			continue
		var round: Dictionary = rounds[current_round]
		if kind == "assistant":
			var assistant_text := str(entry.get("text", "")).strip_edges()
			if not assistant_text.is_empty():
				var existing := str(round.get("assistant", ""))
				round["assistant"] = (
					assistant_text
					if existing.is_empty()
					else existing + "\n" + assistant_text
				)
		elif kind == "tool":
			round["tool_count"] = int(round.get("tool_count", 0)) + 1
		rounds[current_round] = round
	if current_round >= 0 and not _assistant_stream_text.is_empty():
		var round: Dictionary = rounds[current_round]
		var existing := str(round.get("assistant", ""))
		round["assistant"] = (
			_assistant_stream_text
			if existing.is_empty()
			else existing + "\n" + _assistant_stream_text
		)
		rounds[current_round] = round
	return rounds


func _update_round_history(round_lines: PackedInt32Array) -> void:
	if not is_instance_valid(_round_history_rail):
		return
	_round_summaries = _build_round_summaries()
	if _round_summaries.is_empty():
		_round_active_index = -1
		_round_history_rail.visible = false
		_round_preview.visible = false
		return
	var total_lines := maxi(_transcript.get_line_count() - 1, 1)
	for round_index in range(_round_summaries.size()):
		var round: Dictionary = _round_summaries[round_index]
		var fallback_position := (
			0.0
			if _round_summaries.size() <= 1
			else float(round_index) / float(_round_summaries.size() - 1)
		)
		var line := (
			int(round_lines[round_index])
			if round_index < round_lines.size()
			else int(roundf(fallback_position * total_lines))
		)
		round["line"] = line
		round["position"] = (
			clampf(float(line) / float(total_lines), 0.0, 1.0)
			if total_lines > 1
			else fallback_position
		)
		_round_summaries[round_index] = round
	_round_active_index = clampi(
		_round_active_index,
		0,
		_round_summaries.size() - 1
	)
	if _transcript_following:
		_round_active_index = _round_summaries.size() - 1
	_round_history_rail.visible = true
	_round_history_rail.call(
		"set_rounds",
		_round_summaries,
		_round_active_index
	)
	_sync_round_history_search()
	_on_transcript_scroll_changed(_transcript.get_v_scroll_bar().value)


func _on_transcript_scroll_changed(scroll_value: float) -> void:
	if not _transcript_scroll_tracking_suspended:
		_transcript_following = _is_transcript_near_bottom(scroll_value)
		if _transcript_following:
			_transcript_has_unseen_content = false
		_update_latest_button()
	if _round_summaries.is_empty() or not is_instance_valid(
		_round_history_rail
	):
		return
	var scrollbar := _transcript.get_v_scroll_bar()
	var scroll_range := maxf(scrollbar.max_value - scrollbar.page, 1.0)
	var normalized_scroll := clampf(scroll_value / scroll_range, 0.0, 1.0)
	var active_round := 0
	for round_index in range(_round_summaries.size()):
		if (
			float(_round_summaries[round_index].get("position", 0.0))
			<= normalized_scroll + 0.02
		):
			active_round = round_index
		else:
			break
	if active_round == _round_active_index:
		return
	_round_active_index = active_round
	_round_history_rail.call("set_active_round", _round_active_index)


func _on_round_history_hovered(round_index: int, marker_y: float) -> void:
	if round_index < 0 or round_index >= _round_summaries.size():
		return
	var round: Dictionary = _round_summaries[round_index]
	var user_summary := _single_line_preview(
		str(round.get("user", "")),
		100
	)
	var assistant_summary := _single_line_preview(
		str(round.get("assistant", "")),
		180
	)
	_round_preview_title.text = (
		user_summary if not user_summary.is_empty() else "Untitled request"
	)
	_round_preview_body.text = (
		assistant_summary
		if not assistant_summary.is_empty()
		else "Waiting for Godex…"
	)
	var meta := "Round %d of %d" % [
		round_index + 1,
		_round_summaries.size(),
	]
	var tool_count := int(round.get("tool_count", 0))
	if tool_count > 0:
		meta += " · %d tool steps" % tool_count
	meta += " · Click to jump"
	_round_preview_meta.text = meta
	_round_preview_index = round_index
	_round_preview.visible = true
	_layout_round_preview(marker_y)


func _on_round_history_unhovered() -> void:
	_round_preview_index = -1
	if is_instance_valid(_round_preview):
		_round_preview.visible = false


func _on_round_history_activated(round_index: int) -> void:
	if round_index < 0 or round_index >= _round_summaries.size():
		return
	_transcript_following = false
	_update_latest_button()
	_round_active_index = round_index
	_round_history_rail.call("set_active_round", round_index)
	_transcript.scroll_to_line(
		int(_round_summaries[round_index].get("line", 0))
	)


func _layout_round_preview(marker_y: float) -> void:
	if not is_instance_valid(_round_preview) or not _round_preview.visible:
		return
	var available_width := maxf(_transcript_shell.size.x - 46.0, 180.0)
	var preview_width := minf(360.0, available_width)
	var preview_height := minf(
		132.0,
		maxf(_transcript_shell.size.y - 8.0, 80.0)
	)
	_round_preview.size = Vector2(preview_width, preview_height)
	_round_preview.position = Vector2(
		maxf(_transcript_shell.size.x - 38.0 - preview_width, 4.0),
		clampf(
			marker_y - preview_height * 0.5,
			4.0,
			maxf(_transcript_shell.size.y - preview_height - 4.0, 4.0)
		)
	)


func _layout_new_content_button() -> void:
	if not is_instance_valid(_new_content_button):
		return
	_new_content_button.reset_size()
	var button_size := _new_content_button.get_combined_minimum_size()
	_new_content_button.size = button_size
	var transcript_width := maxf(_transcript_shell.size.x - 30.0, 0.0)
	_new_content_button.position = Vector2(
		maxf((transcript_width - button_size.x) * 0.5, 4.0),
		maxf(_transcript_shell.size.y - button_size.y - 12.0, 4.0)
	)


func _layout_search_panel() -> void:
	if not is_instance_valid(_search_panel):
		return
	var available_width := maxf(_transcript_shell.size.x - 42.0, 170.0)
	var search_width := minf(340.0, available_width)
	_search_panel.size = Vector2(
		search_width,
		maxf(_search_panel.get_combined_minimum_size().y, 32.0)
	)
	_search_panel.position = Vector2(
		maxf(_transcript_shell.size.x - 34.0 - search_width, 4.0),
		4.0
	)


func _on_transcript_shell_resized() -> void:
	_layout_new_content_button()
	_layout_search_panel()
	if (
		_round_preview_index < 0
		or _round_preview_index >= _round_summaries.size()
	):
		return
	var position := float(
		_round_summaries[_round_preview_index].get("position", 0.0)
	)
	var marker_y := lerpf(
		8.0,
		maxf(_transcript_shell.size.y - 8.0, 8.0),
		clampf(position, 0.0, 1.0)
	)
	_layout_round_preview(marker_y)


func _render_transcript_entry(entry: Dictionary) -> void:
	match str(entry.get("kind", "")):
		"user":
			_render_user_message(str(entry.get("text", "")))
		"assistant":
			_render_assistant_message(str(entry.get("text", "")))
		"system":
			_render_system_message(str(entry.get("text", "")))
		"activity":
			_render_activity(str(entry.get("text", "")))
		"error":
			_render_error(str(entry.get("text", "")))
		"tool":
			_render_tool_card(entry)


func _render_user_message(text: String) -> void:
	_transcript.push_color(Color(0.36, 0.72, 1.0))
	_transcript.push_bold()
	_transcript.add_text("You\n")
	_transcript.pop()
	_transcript.pop()
	_transcript.add_text(text)
	_transcript.add_text("\n\n")


func _render_assistant_message(text: String) -> void:
	_transcript.push_color(Color(0.43, 0.86, 0.60))
	_transcript.push_bold()
	_transcript.add_text("Godex\n")
	_transcript.pop()
	_transcript.pop()
	_append_markdown(text)
	_transcript.add_text("\n\n")


func _render_system_message(text: String) -> void:
	_transcript.push_color(Color(0.65, 0.68, 0.72))
	_transcript.add_text(text + "\n\n")
	_transcript.pop()


func _render_activity(text: String) -> void:
	_transcript.push_color(Color(0.65, 0.68, 0.72))
	_transcript.add_text("• " + text + "\n")
	_transcript.pop()


func _render_error(text: String) -> void:
	_transcript.push_color(Color(0.94, 0.36, 0.36))
	_transcript.push_bold()
	_transcript.add_text("Error\n")
	_transcript.pop()
	_transcript.add_text(text + "\n\n")
	_transcript.pop()


func _render_tool_card(entry: Dictionary) -> void:
	var entry_id := int(entry.get("id", 0))
	var expanded := bool(entry.get("expanded", false))
	var status := str(entry.get("status", "running"))
	var status_color := Color(0.95, 0.70, 0.25)
	var status_text := "In progress"
	if status in ["completed", "success"]:
		status_color = Color(0.43, 0.86, 0.60)
		status_text = "Completed"
	elif status in ["failed", "error"]:
		status_color = Color(0.94, 0.36, 0.36)
		status_text = "Failed"
	_transcript.push_bgcolor(Color(0.10, 0.11, 0.14, 0.75))
	_transcript.push_meta(
		{"kind": "toggle_tool_card", "id": entry_id},
		RichTextLabel.META_UNDERLINE_ON_HOVER,
		"Expand or collapse"
	)
	_transcript.add_text("▼ " if expanded else "▶ ")
	_transcript.pop()
	_transcript.push_bold()
	_transcript.add_text(str(entry.get("title", "Tool")))
	_transcript.pop()
	var summary := str(entry.get("summary", "")).strip_edges()
	if not summary.is_empty():
		_transcript.add_text(" · " + summary)
	_transcript.push_color(status_color)
	_transcript.add_text("  " + status_text)
	_transcript.pop()
	_transcript.add_text("\n")
	if expanded:
		var details := str(entry.get("details", "")).strip_edges()
		if details.is_empty():
			details = "No detailed output"
		_transcript.push_mono()
		_append_plain_with_file_links(details)
		_transcript.pop()
		_transcript.add_text("\n")
	_transcript.pop()
	var images_value: Variant = entry.get("images", [])
	if typeof(images_value) == TYPE_ARRAY:
		for image_source_value in images_value as Array:
			_append_image_preview(
				str(image_source_value),
				"Generated image"
			)
	_transcript.add_text("\n")


func _image_data_bytes(source: String) -> PackedByteArray:
	if not source.begins_with("data:image/"):
		return PackedByteArray()
	var comma_index := source.find(",")
	if comma_index < 0:
		return PackedByteArray()
	var header := source.left(comma_index)
	if not ";base64" in header:
		return PackedByteArray()
	return Marshalls.base64_to_raw(source.substr(comma_index + 1))


func _image_from_source(source: String) -> Image:
	var normalized := _normalize_image_source(source)
	var image := Image.new()
	var load_error := ERR_UNAVAILABLE
	if normalized.begins_with("data:image/"):
		var bytes := _image_data_bytes(normalized)
		if bytes.is_empty():
			return null
		match _image_extension_from_source(normalized):
			"png":
				load_error = image.load_png_from_buffer(bytes)
			"jpg", "jpeg":
				load_error = image.load_jpg_from_buffer(bytes)
			"webp":
				load_error = image.load_webp_from_buffer(bytes)
			"svg":
				load_error = image.load_svg_from_buffer(bytes)
			_:
				load_error = ERR_FILE_UNRECOGNIZED
	else:
		var local_path := _image_local_path(normalized)
		if local_path.is_empty() or not FileAccess.file_exists(local_path):
			return null
		load_error = image.load(local_path)
	if load_error != OK or image.is_empty():
		return null
	return image


func _image_cache_key(source: String) -> String:
	var normalized := _normalize_image_source(source)
	if normalized.begins_with("data:image/"):
		return "data:%d:%d" % [normalized.length(), normalized.hash()]
	return normalized


func _cached_image_texture(source: String) -> Texture2D:
	var cache_key := _image_cache_key(source)
	var cached: Variant = _image_texture_cache.get(cache_key)
	if cached is Texture2D and is_instance_valid(cached):
		return cached as Texture2D
	return null


func _image_texture_from_source(source: String) -> Texture2D:
	var normalized := _normalize_image_source(source)
	var cache_key := _image_cache_key(normalized)
	var cached := _cached_image_texture(normalized)
	if cached != null:
		_image_texture_cache_order.erase(cache_key)
		_image_texture_cache_order.append(cache_key)
		return cached
	var image := _image_from_source(normalized)
	if image == null:
		return null
	var image_size := image.get_size()
	var longest_side := maxf(image_size.x, image_size.y)
	if longest_side > 1280.0:
		var scale := 1280.0 / longest_side
		image.resize(
			maxi(int(round(image_size.x * scale)), 1),
			maxi(int(round(image_size.y * scale)), 1),
			Image.INTERPOLATE_LANCZOS
		)
	var texture := ImageTexture.create_from_image(image)
	_image_texture_cache[cache_key] = texture
	_image_texture_cache_order.erase(cache_key)
	_image_texture_cache_order.append(cache_key)
	while _image_texture_cache_order.size() > 8:
		var expired_key := _image_texture_cache_order[0]
		_image_texture_cache_order.remove_at(0)
		_image_texture_cache.erase(expired_key)
	return texture


func _image_source_token(source: String) -> String:
	var normalized := _normalize_image_source(source)
	var cache_key := _image_cache_key(normalized)
	var existing_token := str(_image_token_by_cache_key.get(cache_key, ""))
	if not existing_token.is_empty():
		_image_source_by_token[existing_token] = normalized
		return existing_token
	var token := "image_%d" % _next_image_token
	_next_image_token += 1
	_image_token_by_cache_key[cache_key] = token
	_image_source_by_token[token] = normalized
	return token


func _image_source_from_meta(meta: Dictionary) -> String:
	return str(
		_image_source_by_token.get(str(meta.get("image_token", "")), "")
	)


func _queue_image_preview_load(source: String) -> void:
	var normalized := _normalize_image_source(source)
	var cache_key := _image_cache_key(normalized)
	if (
		_cached_image_texture(normalized) != null
		or bool(_image_failed_sources.get(cache_key, false))
		or bool(_image_load_queued_keys.get(cache_key, false))
	):
		return
	_image_load_queue.append(normalized)
	_image_load_queued_keys[cache_key] = true
	if not _image_load_scheduled:
		_image_load_scheduled = true
		call_deferred("_load_next_image_preview")


func _load_next_image_preview() -> void:
	_image_load_scheduled = false
	while not _image_load_queue.is_empty():
		var source: String = _image_load_queue.pop_front()
		var cache_key := _image_cache_key(source)
		_image_load_queued_keys.erase(cache_key)
		if _cached_image_texture(source) != null:
			continue
		var texture := _image_texture_from_source(source)
		if texture == null:
			_image_failed_sources[cache_key] = true
		break
		_image_failed_sources.erase(cache_key)
		break
	_request_transcript_render(true, false)
	if not _image_load_queue.is_empty():
		_image_load_scheduled = true
		call_deferred("_load_next_image_preview")


func _load_image_preview_on_demand(image_token: String) -> void:
	var source := str(_image_source_by_token.get(image_token, ""))
	if source.is_empty():
		return
	var cache_key := _image_cache_key(source)
	_history_image_sources_on_demand.erase(cache_key)
	_image_failed_sources.erase(cache_key)
	_queue_image_preview_load(source)
	_request_transcript_render(true, false)


func _retry_image_preview(image_token: String) -> void:
	var source := str(_image_source_by_token.get(image_token, ""))
	if source.is_empty():
		return
	var cache_key := _image_cache_key(source)
	_image_failed_sources.erase(cache_key)
	_image_texture_cache.erase(cache_key)
	_image_texture_cache_order.erase(cache_key)
	_history_image_sources_on_demand.erase(cache_key)
	_queue_image_preview_load(source)
	_request_transcript_render(true, false)


func _image_local_path(source: String) -> String:
	var normalized := _normalize_image_source(source)
	if (
		normalized.begins_with("data:image/")
		or normalized.begins_with("http://")
		or normalized.begins_with("https://")
	):
		return ""
	if normalized.begins_with("res://"):
		return ProjectSettings.globalize_path(normalized)
	if normalized.is_absolute_path():
		return normalized
	return ""


func _image_display_label(source: String, fallback := "Generated image") -> String:
	var normalized := _normalize_image_source(source)
	if normalized.begins_with("data:image/"):
		var extension := _image_extension_from_source(normalized).to_upper()
		return "%s%s" % [
			fallback,
			" · " + extension if not extension.is_empty() else "",
		]
	var clean_url := normalized.get_slice("?", 0)
	var filename := clean_url.get_file()
	return filename if not filename.is_empty() else fallback


func _append_image_action(
	label: String,
	meta: Dictionary,
	tooltip: String
) -> void:
	_transcript.push_bgcolor(Color(0.15, 0.28, 0.43, 0.95))
	_transcript.push_color(Color(0.90, 0.95, 1.0))
	_transcript.push_font_size(12)
	_transcript.push_bold()
	_transcript.push_meta(
		meta,
		RichTextLabel.META_UNDERLINE_ON_HOVER,
		tooltip
	)
	_transcript.add_text("\u00a0" + label.replace(" ", "\u00a0") + "\u00a0")
	_transcript.pop()
	_transcript.pop()
	_transcript.pop()
	_transcript.pop()
	_transcript.pop()


func _append_image_preview(source: String, alt_text := "Generated image") -> bool:
	var normalized := _normalize_image_source(source)
	if not _looks_like_image_source(normalized):
		return false
	var image_token := _image_source_token(normalized)
	var cache_key := _image_cache_key(normalized)
	var is_remote := (
		normalized.begins_with("http://")
		or normalized.begins_with("https://")
	)
	if _collecting_history_images:
		_history_image_sources_on_demand[cache_key] = true
	var texture := _cached_image_texture(normalized)
	if texture == null:
		_transcript.push_bgcolor(Color(0.10, 0.11, 0.14, 0.85))
		_transcript.push_color(Color(0.70, 0.74, 0.81))
		if is_remote:
			_transcript.add_text("  Remote image  ")
		elif bool(_image_failed_sources.get(cache_key, false)):
			_transcript.add_text("  Image preview failed to load  ")
		elif bool(_history_image_sources_on_demand.get(cache_key, false)):
			_transcript.add_text("  Historical image preview  ")
		else:
			_transcript.add_text("  Loading image preview…  ")
			_queue_image_preview_load(normalized)
		_transcript.pop()
		_transcript.pop()
		_transcript.add_text(" ")
		if is_remote:
			_append_image_action(
				"↗ Open image",
				{
					"kind": "open_image_source",
					"image_token": image_token,
				},
				normalized
			)
		elif bool(_image_failed_sources.get(cache_key, false)):
			_append_image_action(
				"↻ Retry",
				{
					"kind": "retry_image",
					"image_token": image_token,
				},
				"Reload image"
			)
		elif bool(_history_image_sources_on_demand.get(cache_key, false)):
			_append_image_action(
				"▶ Load preview",
				{
					"kind": "load_image_preview",
					"image_token": image_token,
				},
				"Decode this historical image only after clicking"
			)
		else:
			_transcript.push_color(Color(0.52, 0.57, 0.65))
			_transcript.add_text("Please wait")
			_transcript.pop()
		_transcript.add_text("\n")
		return true

	var image_size := texture.get_size()
	var available_width := maxf(_transcript.size.x - 54.0, 180.0)
	var max_width := minf(available_width, 520.0)
	var max_height := 340.0
	var scale := minf(
		1.0,
		minf(
			max_width / maxf(image_size.x, 1.0),
			max_height / maxf(image_size.y, 1.0)
		)
	)
	var preview_width := maxi(int(round(image_size.x * scale)), 1)
	var preview_height := maxi(int(round(image_size.y * scale)), 1)
	var label := _image_display_label(normalized, alt_text)
	_transcript.push_meta(
		{
			"kind": "image_preview",
			"image_token": image_token,
			"label": label,
		},
		RichTextLabel.META_UNDERLINE_ON_HOVER,
		"Click to view full size · %s" % label
	)
	_transcript.add_image(texture, preview_width, preview_height)
	_transcript.pop()
	_transcript.add_text("\n")
	_append_image_action(
		"⤢ Full size",
		{
			"kind": "image_preview",
			"image_token": image_token,
			"label": label,
		},
		"Open full-size preview"
	)
	_transcript.add_text(" ")
	_append_image_action(
		"⧉ Copy image",
		{
			"kind": "copy_image",
			"image_token": image_token,
		},
		"Copy the image to the system clipboard"
	)
	_transcript.add_text(" ")
	_append_image_action(
		"⇩ Save",
		{
			"kind": "save_image",
			"image_token": image_token,
		},
		"Save the image as a file"
	)
	if not normalized.begins_with("data:image/"):
		_transcript.add_text(" ")
		_append_image_action(
			"↗ Location",
			{
				"kind": "open_image_source",
				"image_token": image_token,
			},
			"Open the image or its location"
		)
		_transcript.add_text(" ")
		_append_image_action(
			"⧉ Path",
			{
				"kind": "copy_image_path",
				"image_token": image_token,
			},
			"Copy image path"
		)
	_transcript.add_text("\n")
	return true


func _show_image_preview(source: String, label := "") -> void:
	var normalized := _normalize_image_source(source)
	var full_image := _image_from_source(normalized)
	var texture := (
		ImageTexture.create_from_image(full_image)
		if full_image != null
		else _cached_image_texture(normalized)
	)
	if texture == null:
		if normalized.begins_with("http://") or normalized.begins_with("https://"):
			OS.shell_open(normalized)
		else:
			_show_toast("Could not load image")
		return
	_active_image_source = normalized
	_image_preview_texture.texture = texture
	_image_preview_dialog.title = (
		label if not label.is_empty() else _image_display_label(normalized)
	)
	_image_preview_path_label.text = (
		"Embedded image data"
		if normalized.begins_with("data:image/")
		else normalized
	)
	var has_local_path := not _image_local_path(normalized).is_empty()
	var is_remote := (
		normalized.begins_with("http://")
		or normalized.begins_with("https://")
	)
	_image_preview_save_button.disabled = is_remote
	_image_preview_open_button.disabled = not has_local_path and not is_remote
	_image_preview_copy_button.disabled = normalized.begins_with("data:image/")
	_image_preview_dialog.popup_centered(Vector2i(920, 700))


func _request_image_save(source: String) -> void:
	var normalized := _normalize_image_source(source)
	if (
		not normalized.begins_with("data:image/")
		and _image_local_path(normalized).is_empty()
	):
		OS.shell_open(normalized)
		return
	_pending_image_save_source = normalized
	var extension := _image_extension_from_source(normalized)
	if extension.is_empty():
		extension = "png"
	var local_path := _image_local_path(normalized)
	_image_save_dialog.current_file = (
		local_path.get_file()
		if not local_path.is_empty()
		else "generated-image.%s" % extension
	)
	_image_save_dialog.popup_centered_ratio(0.72)


func _save_active_image() -> void:
	if not _active_image_source.is_empty():
		_request_image_save(_active_image_source)


func _on_image_save_file_selected(target_path: String) -> void:
	var source := _pending_image_save_source
	_pending_image_save_source = ""
	if source.is_empty() or target_path.is_empty():
		return
	var save_error := OK
	if source.begins_with("data:image/"):
		var bytes := _image_data_bytes(source)
		var output := FileAccess.open(target_path, FileAccess.WRITE)
		if output == null:
			save_error = FileAccess.get_open_error()
		else:
			output.store_buffer(bytes)
			output.close()
	else:
		var local_path := _image_local_path(source)
		if local_path == target_path:
			_show_toast("Image is already at this location")
			return
		save_error = DirAccess.copy_absolute(local_path, target_path)
	if save_error == OK:
		_show_toast("Image saved")
	else:
		push_warning(
			"Godex could not save the image: %s"
			% error_string(save_error)
		)
		_show_toast("Could not save image")


func _open_image_source(source: String) -> void:
	var normalized := _normalize_image_source(source)
	var local_path := _image_local_path(normalized)
	if not local_path.is_empty():
		OS.shell_show_in_file_manager(local_path)
	elif normalized.begins_with("http://") or normalized.begins_with("https://"):
		OS.shell_open(normalized)


func _open_active_image_location() -> void:
	if not _active_image_source.is_empty():
		_open_image_source(_active_image_source)


func _copy_image_path(source: String) -> void:
	var normalized := _normalize_image_source(source)
	if normalized.begins_with("data:image/"):
		return
	var local_path := _image_local_path(normalized)
	DisplayServer.clipboard_set(
		local_path if not local_path.is_empty() else normalized
	)
	_show_copy_toast()


func _windows_image_clipboard_script(image_path: String) -> String:
	var escaped_path := image_path.replace("'", "''")
	return (
		"$ErrorActionPreference = 'Stop'\n"
		+ "$path = '%s'\n" % escaped_path
		+ "try {\n"
		+ "  Add-Type -AssemblyName System.Windows.Forms\n"
		+ "  Add-Type -AssemblyName System.Drawing\n"
		+ "  $image = [System.Drawing.Image]::FromFile($path)\n"
		+ "  try {\n"
		+ "    $copied = $false\n"
		+ "    for ($attempt = 0; $attempt -lt 5; $attempt++) {\n"
		+ "      try {\n"
		+ "        [System.Windows.Forms.Clipboard]::SetImage($image)\n"
		+ "        $copied = $true\n"
		+ "        break\n"
		+ "      } catch {\n"
		+ "        Start-Sleep -Milliseconds 80\n"
		+ "      }\n"
		+ "    }\n"
		+ "    if (-not $copied) { throw 'Clipboard is unavailable.' }\n"
		+ "  } finally {\n"
		+ "    if ($null -ne $image) { $image.Dispose() }\n"
		+ "  }\n"
		+ "} finally {\n"
		+ "  Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue\n"
		+ "}\n"
	)


func _copy_image_to_clipboard(source: String) -> void:
	if OS.get_name() != "Windows":
		_show_toast("Copying images is not supported on this platform")
		return
	var normalized := _normalize_image_source(source)
	var image := _image_from_source(normalized)
	if image == null:
		_show_toast("Could not copy image")
		return
	var temporary_path := ProjectSettings.globalize_path(
		"user://godex_clipboard_%d.png" % Time.get_ticks_usec()
	)
	var save_error := image.save_png(temporary_path)
	if save_error != OK:
		push_warning(
			"Godex could not prepare the clipboard image: %s"
			% error_string(save_error)
		)
		_show_toast("Could not copy image")
		return
	var script := _windows_image_clipboard_script(temporary_path)
	var encoded_command := Marshalls.raw_to_base64(script.to_utf16_buffer())
	var process_id := OS.create_process(
		"powershell.exe",
		PackedStringArray([
			"-NoProfile",
			"-NonInteractive",
			"-STA",
			"-WindowStyle",
			"Hidden",
			"-EncodedCommand",
			encoded_command,
		]),
		false
	)
	if process_id <= 0:
		DirAccess.remove_absolute(temporary_path)
		push_warning("Godex could not start the Windows image clipboard bridge process.")
		_show_toast("Could not copy image")
		return
	_show_toast("Image copied")


func _copy_active_image_path() -> void:
	if not _active_image_source.is_empty():
		_copy_image_path(_active_image_source)


func _append_user_message(text: String) -> void:
	_transcript_entries.append({"kind": "user", "text": text})
	_request_transcript_render(true)


func _append_assistant_message(text: String) -> void:
	_transcript_entries.append({"kind": "assistant", "text": text})
	_request_transcript_render(true)


func _append_markdown(markdown: String) -> void:
	var lines := markdown.split("\n", true)
	var line_index := 0
	while line_index < lines.size():
		var line := str(lines[line_index])
		if line.strip_edges().begins_with("```"):
			var fence_info := line.strip_edges().trim_prefix("```").strip_edges()
			var code_lines := PackedStringArray()
			line_index += 1
			while (
				line_index < lines.size()
				and not str(lines[line_index]).strip_edges().begins_with("```")
			):
				code_lines.append(str(lines[line_index]))
				line_index += 1
			_append_code_block(fence_info, "\n".join(code_lines))
			if line_index < lines.size():
				line_index += 1
			if line_index < lines.size():
				_transcript.add_text("\n")
			continue
		_append_markdown_line(line)
		line_index += 1
		if line_index < lines.size():
			_transcript.add_text("\n")


func _code_block_file_meta(fence_info: String, code: String) -> Dictionary:
	var path_regex := RegEx.new()
	var compile_error := path_regex.compile(
		"(?:res://|[A-Za-z]:[\\\\/])"
		+ "[^\\s\\]\\)\\}\\>,;]+"
		+ "\\.(?:gd|tscn|tres|cs|shader|gdshader|json|toml|cfg|md)"
		+ "(?::\\d+|#L\\d+)?"
	)
	if compile_error != OK:
		return {}
	var searchable := fence_info + "\n" + code.left(800)
	var result := path_regex.search(searchable)
	if result == null:
		return {}
	return _file_meta_from_target(result.get_string())


func _append_code_block(fence_info: String, code: String) -> void:
	var language := fence_info
	if " " in language:
		language = language.get_slice(" ", 0)
	if language.is_empty():
		language = "code"
	var file_meta := _code_block_file_meta(fence_info, code)
	var code_background := Color(0.08, 0.09, 0.11, 0.90)
	_transcript.push_table(1)
	_transcript.set_table_column_expand(0, true, 1, false)
	_transcript.push_cell()
	_transcript.set_cell_row_background_color(
		code_background,
		code_background
	)
	_transcript.set_cell_border_color(Color(0.18, 0.20, 0.24, 0.90))
	_transcript.set_cell_padding(Rect2(5.0, 4.0, 5.0, 4.0))
	var header_columns := 5 if not file_meta.is_empty() else 3
	_transcript.push_table(header_columns)
	_transcript.set_table_column_expand(0, true, 1, true)
	for column_index in range(1, header_columns):
		_transcript.set_table_column_expand(column_index, false, 1, true)
	_transcript.push_cell()
	_transcript.set_cell_padding(Rect2(0.0, 0.0, 4.0, 0.0))
	_transcript.push_color(Color(0.72, 0.76, 0.82))
	_transcript.push_font_size(12)
	_transcript.push_bold()
	_transcript.add_text(language)
	_transcript.pop()
	_transcript.pop()
	_transcript.pop()
	_transcript.pop()
	_append_code_action_spacer()
	_append_code_action(
		"⧉ Copy",
		{"kind": "copy_code", "code": code},
		"Copy code block to clipboard",
		Color(0.16, 0.38, 0.64, 1.0)
	)
	if not file_meta.is_empty():
		var line_number := int(file_meta.get("line", 0))
		_append_code_action_spacer()
		_append_code_action(
			(
				"→ L%d" % line_number
				if line_number > 0
				else "↗ Open"
			),
			file_meta,
			str(file_meta.get("path", "Open file")),
			Color(0.16, 0.48, 0.36, 1.0)
		)
	_transcript.pop()
	_transcript.add_text("\n")
	_transcript.push_mono()
	_transcript.add_text(code)
	_transcript.pop()
	_transcript.pop()
	_transcript.pop()


func _append_code_action(
	label: String,
	meta: Dictionary,
	tooltip: String,
	background: Color
) -> void:
	_transcript.push_cell()
	_transcript.set_cell_padding(Rect2(0.0, 0.0, 0.0, 0.0))
	_transcript.push_bgcolor(background)
	_transcript.push_color(Color(0.96, 0.98, 1.0))
	_transcript.push_font_size(12)
	_transcript.push_bold()
	_transcript.push_meta(
		meta,
		RichTextLabel.META_UNDERLINE_ON_HOVER,
		tooltip
	)
	_transcript.add_text(
		"\u00a0" + label.replace(" ", "\u00a0") + "\u00a0"
	)
	_transcript.pop()
	_transcript.pop()
	_transcript.pop()
	_transcript.pop()
	_transcript.pop()
	_transcript.pop()


func _append_code_action_spacer() -> void:
	_transcript.push_cell()
	_transcript.set_cell_padding(Rect2(2.0, 0.0, 2.0, 0.0))
	_transcript.add_text("\u2009")
	_transcript.pop()


func _append_markdown_line(line: String) -> void:
	var content := line
	if content.begins_with("### "):
		_transcript.push_bold()
		_append_inline_markdown(content.substr(4))
		_transcript.pop()
		return
	if content.begins_with("## "):
		_transcript.push_bold()
		_append_inline_markdown(content.substr(3))
		_transcript.pop()
		return
	if content.begins_with("# "):
		_transcript.push_bold()
		_append_inline_markdown(content.substr(2))
		_transcript.pop()
		return
	if content.begins_with("- ") or content.begins_with("* "):
		_transcript.add_text("• ")
		_append_inline_markdown(content.substr(2))
		return
	if content.begins_with("> "):
		_transcript.push_color(Color(0.65, 0.68, 0.72))
		_transcript.add_text("│ ")
		_append_inline_markdown(content.substr(2))
		_transcript.pop()
		return

	var ordered_prefix_length := _ordered_list_prefix_length(content)
	if ordered_prefix_length > 0:
		_transcript.add_text(content.left(ordered_prefix_length))
		_append_inline_markdown(content.substr(ordered_prefix_length))
		return
	_append_inline_markdown(content)


func _ordered_list_prefix_length(line: String) -> int:
	var digit_count := 0
	while (
		digit_count < line.length()
		and line.substr(digit_count, 1).is_valid_int()
	):
		digit_count += 1
	if (
		digit_count > 0
		and digit_count + 1 < line.length()
		and line.substr(digit_count, 2) == ". "
	):
		return digit_count + 2
	return 0


func _append_inline_markdown(text: String) -> void:
	var cursor := 0
	while cursor < text.length():
		if text.substr(cursor, 2) == "![":
			var image_label_end := text.find("](", cursor + 2)
			if image_label_end >= 0:
				var image_target_end := text.find(")", image_label_end + 2)
				if image_target_end >= 0:
					var image_label := text.substr(
						cursor + 2,
						image_label_end - cursor - 2
					)
					var image_target := text.substr(
						image_label_end + 2,
						image_target_end - image_label_end - 2
					)
					if _append_image_preview(image_target, image_label):
						cursor = image_target_end + 1
						continue

		if text.substr(cursor, 2) == "**":
			var bold_end := text.find("**", cursor + 2)
			if bold_end >= 0:
				_transcript.push_bold()
				_append_plain_with_file_links(
					text.substr(cursor + 2, bold_end - cursor - 2)
				)
				_transcript.pop()
				cursor = bold_end + 2
				continue

		if text.substr(cursor, 1) == "`":
			var code_end := text.find("`", cursor + 1)
			if code_end >= 0:
				_transcript.push_mono()
				_transcript.push_bgcolor(Color(0.12, 0.13, 0.16, 0.85))
				_transcript.add_text(
					text.substr(cursor + 1, code_end - cursor - 1)
				)
				_transcript.pop()
				_transcript.pop()
				cursor = code_end + 1
				continue

		if text.substr(cursor, 1) == "[":
			var label_end := text.find("](", cursor + 1)
			if label_end >= 0:
				var target_end := text.find(")", label_end + 2)
				if target_end >= 0:
					var label := text.substr(
						cursor + 1,
						label_end - cursor - 1
					)
					var target := text.substr(
						label_end + 2,
						target_end - label_end - 2
					)
					_append_markdown_link(label, target)
					cursor = target_end + 1
					continue

		var next_token := text.length()
		for token in ["![", "**", "`", "["]:
			var token_index := text.find(token, cursor + 1)
			if token_index >= 0:
				next_token = mini(next_token, token_index)
		_append_plain_with_file_links(text.substr(cursor, next_token - cursor))
		cursor = next_token


func _append_markdown_link(label: String, target: String) -> void:
	var cleaned_target := target.strip_edges()
	if cleaned_target.begins_with("<") and cleaned_target.ends_with(">"):
		cleaned_target = cleaned_target.substr(1, cleaned_target.length() - 2)

	if (
		cleaned_target.begins_with("https://")
		or cleaned_target.begins_with("http://")
	):
		_transcript.push_meta(
			{"kind": "url", "url": cleaned_target},
			RichTextLabel.META_UNDERLINE_ON_HOVER,
			cleaned_target
		)
		_transcript.add_text(label)
		_transcript.pop()
		return

	var file_meta := _file_meta_from_target(cleaned_target)
	if not file_meta.is_empty():
		_transcript.push_meta(
			file_meta,
			RichTextLabel.META_UNDERLINE_ON_HOVER,
			str(file_meta.get("path", cleaned_target))
		)
		_transcript.add_text(label)
		_transcript.pop()
		return
	_transcript.add_text(label)


func _append_plain_with_file_links(text: String) -> void:
	if text.is_empty():
		return
	var file_regex := RegEx.new()
	var compile_error := file_regex.compile(
		"(?:res://|[A-Za-z]:[\\\\/])"
		+ "[^\\s\\]\\)\\}\\>,;]+"
		+ "\\.(?:gd|tscn|tres|cs|shader|gdshader|json|toml|cfg|md)"
		+ "(?::\\d+)?"
	)
	if compile_error != OK:
		_transcript.add_text(text)
		return

	var cursor := 0
	for match_result in file_regex.search_all(text):
		var match_start := match_result.get_start()
		var match_end := match_result.get_end()
		if match_start > cursor:
			_transcript.add_text(text.substr(cursor, match_start - cursor))
		var matched_target := match_result.get_string()
		var file_meta := _file_meta_from_target(matched_target)
		if file_meta.is_empty():
			_transcript.add_text(matched_target)
		else:
			_transcript.push_meta(
				file_meta,
				RichTextLabel.META_UNDERLINE_ON_HOVER,
				str(file_meta.get("path", matched_target))
			)
			_transcript.add_text(matched_target)
			_transcript.pop()
		cursor = match_end
	if cursor < text.length():
		_transcript.add_text(text.substr(cursor))


func _file_meta_from_target(target: String) -> Dictionary:
	var path := target.strip_edges()
	if path.begins_with("file://"):
		path = path.trim_prefix("file://")

	var line_number := 0
	var line_anchor := path.rfind("#L")
	if line_anchor >= 0:
		var anchor_value := path.substr(line_anchor + 2)
		if anchor_value.is_valid_int():
			line_number = int(anchor_value)
			path = path.left(line_anchor)
	else:
		var last_colon := path.rfind(":")
		if last_colon > 1:
			var line_value := path.substr(last_colon + 1)
			if line_value.is_valid_int():
				line_number = int(line_value)
				path = path.left(last_colon)

	if path.begins_with("res://") or path.is_absolute_path():
		return {"kind": "file", "path": path, "line": line_number}
	var relative_resource_path := "res://" + path.trim_prefix("./")
	if FileAccess.file_exists(relative_resource_path):
		return {
			"kind": "file",
			"path": relative_resource_path,
			"line": line_number,
		}
	return {}


func _on_transcript_meta_clicked(meta: Variant) -> void:
	if typeof(meta) != TYPE_DICTIONARY:
		return
	var meta_data: Dictionary = meta as Dictionary
	match str(meta_data.get("kind", "")):
		"url":
			OS.shell_open(str(meta_data.get("url", "")))
		"file":
			call_deferred(
				"_open_file_reference",
				str(meta_data.get("path", "")),
				int(meta_data.get("line", 0))
			)
		"copy_code":
			DisplayServer.clipboard_set(str(meta_data.get("code", "")))
			_show_copy_toast()
		"image_preview":
			_show_image_preview(
				_image_source_from_meta(meta_data),
				str(meta_data.get("label", ""))
			)
		"save_image":
			_request_image_save(_image_source_from_meta(meta_data))
		"copy_image":
			_copy_image_to_clipboard(_image_source_from_meta(meta_data))
		"open_image_source":
			_open_image_source(_image_source_from_meta(meta_data))
		"copy_image_path":
			_copy_image_path(_image_source_from_meta(meta_data))
		"load_image_preview":
			_load_image_preview_on_demand(
				str(meta_data.get("image_token", ""))
			)
		"retry_image":
			_retry_image_preview(
				str(meta_data.get("image_token", ""))
			)
		"toggle_tool_card":
			var entry_id := int(meta_data.get("id", 0))
			for entry_index in range(_transcript_entries.size()):
				if int(_transcript_entries[entry_index].get("id", 0)) == entry_id:
					_transcript_entries[entry_index]["expanded"] = not bool(
						_transcript_entries[entry_index].get("expanded", false)
					)
					_request_transcript_render(true, false)
					break


func _show_toast(message: String) -> void:
	if not is_instance_valid(_copy_toast):
		return
	if is_instance_valid(_copy_toast_label):
		_copy_toast_label.text = message
	if _copy_toast_tween != null and _copy_toast_tween.is_valid():
		_copy_toast_tween.kill()
	_copy_toast.reset_size()
	var toast_size := _copy_toast.get_combined_minimum_size()
	_copy_toast.size = toast_size
	var mouse_position := _transcript_shell.get_local_mouse_position()
	_copy_toast.position = Vector2(
		clampf(
			mouse_position.x + 10.0,
			4.0,
			maxf(_transcript_shell.size.x - toast_size.x - 4.0, 4.0)
		),
		clampf(
			mouse_position.y + 12.0,
			4.0,
			maxf(_transcript_shell.size.y - toast_size.y - 4.0, 4.0)
		)
	)
	_copy_toast.modulate = Color.WHITE
	_copy_toast.visible = true
	_copy_toast_timer.start()


func _show_copy_toast() -> void:
	_show_toast("Copied")


func _hide_copy_toast() -> void:
	if not is_instance_valid(_copy_toast) or not _copy_toast.visible:
		return
	_copy_toast_tween = create_tween()
	_copy_toast_tween.tween_property(
		_copy_toast,
		"modulate:a",
		0.0,
		0.18
	)
	_copy_toast_tween.tween_callback(Callable(_copy_toast, "hide"))


func _open_file_reference(path: String, line_number: int) -> void:
	if _editor_interface == null or path.is_empty():
		return
	var resource_path := path.replace("\\", "/")
	if resource_path.is_absolute_path():
		resource_path = ProjectSettings.localize_path(resource_path)
	if not resource_path.begins_with("res://"):
		push_warning("Godex only opens files inside the project: %s" % path)
		return
	if not FileAccess.file_exists(resource_path):
		push_warning("Godex file does not exist: %s" % resource_path)
		return

	_editor_interface.select_file(resource_path)
	if resource_path.get_extension().to_lower() == "tscn":
		_editor_interface.open_scene_from_path(resource_path)
		return
	var resource := ResourceLoader.load(resource_path)
	if resource is Script:
		_editor_interface.set_main_screen_editor("Script")
		_editor_interface.edit_script(
			resource as Script,
			maxi(line_number - 1, -1),
			0,
			true
		)
	elif resource != null:
		_editor_interface.edit_resource(resource)
	else:
		push_warning(
			"Godex selected the file in the FileSystem dock, but Godot cannot edit it directly: %s"
			% resource_path
		)


func _append_system_message(text: String) -> void:
	_transcript_entries.append({"kind": "system", "text": text})
	_request_transcript_render(true)


func _append_activity(text: String) -> void:
	if not is_instance_valid(_transcript):
		return
	_transcript_entries.append({"kind": "activity", "text": text})
	_request_transcript_render(true)


func _append_error(text: String) -> void:
	if not is_instance_valid(_transcript):
		return
	_transcript_entries.append({"kind": "error", "text": text})
	_request_transcript_render(true)
