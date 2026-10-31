extends Node

const STATE_PATH := "user://rec_utility_state.cfg"
const CHEATS_RELATIVE_PATH := "data/cheats.json"
const ADDITIVE_CODES := ["MONEYPLZ", "YODIK", "WEIII"]

var _mod_path := ""
var _scene_tree: SceneTree
var _cheats: Array[Dictionary] = []
var _submitted_codes: Array[String] = []

var _shader_override := false
var _shaders_enabled := true
var _cursor_override := false
var _teleport_cursor_enabled := false

var _canvas: CanvasLayer
var _launcher_button: PanelContainer
var _launcher_idle := 0.0
var _launcher_position_was_saved := false
var _launcher_has_been_used := false
var _launcher_dragging := false
var _launcher_dragged := false
var _launcher_touch_index := -1
var _launcher_press_position := Vector2.ZERO
var _launcher_drag_offset := Vector2.ZERO
var _launcher_saved_position := Vector2(-1.0, -1.0)
const LAUNCHER_FADE_DELAY := 2.5
const LAUNCHER_FADE_DURATION := 0.8
const LAUNCHER_IDLE_ALPHA := 0.45
var _panel: PanelContainer
var _status_label: Label
var _shader_button: Button
var _cursor_button: Button
var _confirm_dialog: ConfirmationDialog
var _diagnostic_dialog: AcceptDialog
var _diagnostic_text: TextEdit
var _code_input: LineEdit
var _pending_code := ""
var _scan_elapsed := 0.0


func initialize(mod_path: String, scene_tree: SceneTree) -> void:
	_mod_path = mod_path
	_scene_tree = scene_tree
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_state()
	_load_cheats()
	# Attach synchronously so GUMMM does not mark this mod active before
	# its node and interface have actually entered the scene tree.
	if not is_inside_tree():
		_scene_tree.root.add_child(self)


func set_enabled(enabled: bool) -> void:
	# GUMMM calls this when the user changes the mod toggle after loading.
	if _canvas != null:
		_canvas.visible = enabled
	process_mode = Node.PROCESS_MODE_ALWAYS if enabled else Node.PROCESS_MODE_DISABLED


func _ready() -> void:
	_build_interface()
	print("REC Utility: GUMM script loaded; ", _cheats.size(), " cheat codes available")
	_set_status("GUMM script loaded. Open REC Settings, then use SCAN REC UI to inspect controls.")


func _process(delta: float) -> void:
	_update_launcher_fade(delta)
	_scan_elapsed += delta
	if _scan_elapsed >= 0.75:
		_scan_elapsed = 0.0
		if _shader_override or _cursor_override:
			_apply_saved_game_settings()


func _load_cheats() -> void:
	var path := _mod_path.path_join(CHEATS_RELATIVE_PATH)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("REC Utility: could not open cheat catalogue: " + path)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Array:
		for entry in parsed:
			if entry is Dictionary and entry.has("code"):
				_cheats.append(entry)


func _load_state() -> void:
	var config := ConfigFile.new()
	if config.load(STATE_PATH) != OK:
		return

	_shader_override = config.get_value("shader", "override", false)
	_shaders_enabled = config.get_value("shader", "enabled", true)
	_cursor_override = config.get_value("cursor", "override", false)
	_teleport_cursor_enabled = config.get_value("cursor", "enabled", false)

	var history: Variant = config.get_value("history", "submitted", [])
	if history is Array:
		for code in history:
			_submitted_codes.append(str(code))
	_launcher_saved_position = config.get_value("launcher", "position", Vector2(-1.0, -1.0))
	_launcher_position_was_saved = _launcher_saved_position.x >= 0.0 and _launcher_saved_position.y >= 0.0


func _save_state() -> void:
	var config := ConfigFile.new()
	config.set_value("shader", "override", _shader_override)
	config.set_value("shader", "enabled", _shaders_enabled)
	config.set_value("cursor", "override", _cursor_override)
	config.set_value("cursor", "enabled", _teleport_cursor_enabled)
	config.set_value("history", "submitted", _submitted_codes)
	if _launcher_button != null:
		config.set_value("launcher", "position", _launcher_button.position)
	var error := config.save(STATE_PATH)
	if error != OK:
		push_warning("REC Utility: could not save preferences")


func _build_interface() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 256
	add_child(_canvas)

	var viewport := get_viewport().get_visible_rect().size
	var margin := 12.0
	var panel_width := minf(420.0, viewport.x - margin * 2.0)
	var panel_height := minf(560.0, viewport.y - margin * 2.0)

	_launcher_button = PanelContainer.new()
	_launcher_button.custom_minimum_size = Vector2(50.0, 50.0)
	_launcher_button.size = Vector2(50.0, 50.0)
	_launcher_button.position = _launcher_saved_position if _launcher_position_was_saved else Vector2(maxf(6.0, viewport.x - 62.0), maxf(6.0, viewport.y - 62.0))
	_launcher_button.position = _clamp_launcher_position(_launcher_button.position)
	_launcher_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_launcher_button.add_theme_stylebox_override("panel", _make_style(Color("#8f3f1f"), Color("#e58a3a"), 25))
	var launcher_label := Label.new()
	launcher_label.text = "REC+"
	launcher_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	launcher_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	launcher_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	launcher_label.add_theme_color_override("font_color", Color("#ffffff"))
	launcher_label.add_theme_font_size_override("font_size", 11)
	_launcher_button.add_child(launcher_label)
	_canvas.add_child(_launcher_button)
	_launcher_button.gui_input.connect(_on_launcher_gui_input)
	_launcher_idle = 0.0

	_panel = PanelContainer.new()
	_panel.position = Vector2((viewport.x - panel_width) / 2.0, (viewport.y - panel_height) / 2.0)
	_panel.size = Vector2(panel_width, panel_height)
	_panel.visible = false
	_panel.add_theme_stylebox_override("panel", _make_style(Color("#28170f"), Color("#bd642d"), 18))
	_canvas.add_child(_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 4)
	_panel.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)

	var title := Label.new()
	title.text = "REC UTILITY"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color("#f6d6a8"))
	title.add_theme_font_size_override("font_size", 14)
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(34.0, 28.0)
	close_button.add_theme_font_size_override("font_size", 11)
	_style_button(close_button, Color("#60301f"), Color("#e58a3a"))
	header.add_child(close_button)
	close_button.pressed.connect(func() -> void: _panel.visible = false)

	_shader_button = Button.new()
	_shader_button.custom_minimum_size = Vector2(0.0, 32.0)
	_shader_button.add_theme_font_size_override("font_size", 11)
	_style_button(_shader_button, Color("#60301f"), Color("#bd642d"))
	layout.add_child(_shader_button)
	_shader_button.pressed.connect(_toggle_shaders)

	_cursor_button = Button.new()
	_cursor_button.custom_minimum_size = Vector2(0.0, 32.0)
	_cursor_button.add_theme_font_size_override("font_size", 11)
	_style_button(_cursor_button, Color("#60301f"), Color("#bd642d"))
	layout.add_child(_cursor_button)
	_cursor_button.pressed.connect(_toggle_teleport_cursor)
	_update_setting_button_text()

	var scan_button := Button.new()
	scan_button.text = "SCAN REC UI"
	scan_button.custom_minimum_size = Vector2(0.0, 29.0)
	scan_button.add_theme_font_size_override("font_size", 10)
	_style_button(scan_button, Color("#75401f"), Color("#e58a3a"))
	layout.add_child(scan_button)
	scan_button.pressed.connect(_show_ui_diagnostics)

	var divider := HSeparator.new()
	layout.add_child(divider)

	var section_title := Label.new()
	section_title.text = "CHEAT CODES  /  SELECT, EDIT OR COPY"
	section_title.add_theme_color_override("font_color", Color("#f6d6a8"))
	section_title.add_theme_font_size_override("font_size", 11)
	layout.add_child(section_title)

	_code_input = LineEdit.new()
	_code_input.placeholder_text = "Tap a code below or type one here"
	_code_input.custom_minimum_size = Vector2(0.0, 34.0)
	_code_input.add_theme_font_size_override("font_size", 12)
	_code_input.add_theme_stylebox_override("normal", _make_style(Color("#1d120d"), Color("#bd642d"), 10))
	_code_input.add_theme_color_override("font_color", Color("#fff0d8"))
	layout.add_child(_code_input)

	var code_actions := HBoxContainer.new()
	code_actions.add_theme_constant_override("separation", 5)
	layout.add_child(code_actions)

	var submit_button := Button.new()
	submit_button.text = "SUBMIT"
	submit_button.custom_minimum_size = Vector2(0.0, 30.0)
	submit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(submit_button, Color("#8f3f1f"), Color("#e58a3a"))
	code_actions.add_child(submit_button)
	submit_button.pressed.connect(_submit_code_from_field)

	var copy_button := Button.new()
	copy_button.text = "COPY"
	copy_button.custom_minimum_size = Vector2(0.0, 30.0)
	copy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(copy_button, Color("#60301f"), Color("#bd642d"))
	code_actions.add_child(copy_button)
	copy_button.pressed.connect(_copy_current_code)

	var copy_all_button := Button.new()
	copy_all_button.text = "COPY ALL"
	copy_all_button.custom_minimum_size = Vector2(0.0, 30.0)
	copy_all_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(copy_all_button, Color("#60301f"), Color("#bd642d"))
	code_actions.add_child(copy_all_button)
	copy_all_button.pressed.connect(_copy_all_codes)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	var cheat_list := VBoxContainer.new()
	cheat_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cheat_list.add_theme_constant_override("separation", 2)
	scroll.add_child(cheat_list)

	for entry in _cheats:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		cheat_list.add_child(row)

		var code_button := Button.new()
		code_button.text = str(entry.get("code", "UNKNOWN"))
		code_button.custom_minimum_size = Vector2(100.0, 31.0)
		code_button.add_theme_font_size_override("font_size", 10)
		_style_button(code_button, Color("#75401f"), Color("#bd642d"))
		row.add_child(code_button)
		code_button.pressed.connect(_select_code.bind(str(entry.get("code", ""))))

		var description := Label.new()
		description.text = str(entry.get("description", ""))
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_color_override("font_color", Color("#ead1b2"))
		description.add_theme_font_size_override("font_size", 10)
		row.add_child(description)

	_status_label = Label.new()
	_status_label.text = "Open REC Settings and keep the cheat box visible."
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(0.0, 28.0)
	_status_label.add_theme_color_override("font_color", Color("#f6d6a8"))
	_status_label.add_theme_font_size_override("font_size", 10)
	layout.add_child(_status_label)

	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "Repeat cheat?"
	_confirm_dialog.dialog_text = "This code may add resources again. Do you want to submit it again?"
	add_child(_confirm_dialog)
	_confirm_dialog.confirmed.connect(_confirm_pending_code)

	_diagnostic_dialog = AcceptDialog.new()
	_diagnostic_dialog.title = "REC UI diagnostics"
	_diagnostic_dialog.min_size = Vector2i(360, 300)
	add_child(_diagnostic_dialog)
	var diagnostic_layout := VBoxContainer.new()
	diagnostic_layout.custom_minimum_size = Vector2(340.0, 280.0)
	diagnostic_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diagnostic_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_diagnostic_dialog.add_child(diagnostic_layout)

	_diagnostic_text = TextEdit.new()
	_diagnostic_text.editable = true
	_diagnostic_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_diagnostic_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_diagnostic_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_diagnostic_text.custom_minimum_size = Vector2(320.0, 240.0)
	_diagnostic_text.add_theme_font_size_override("font_size", 10)
	diagnostic_layout.add_child(_diagnostic_text)

	var diagnostic_copy := Button.new()
	diagnostic_copy.text = "COPY REPORT"
	diagnostic_copy.custom_minimum_size = Vector2(0.0, 32.0)
	_style_button(diagnostic_copy, Color("#75401f"), Color("#e58a3a"))
	diagnostic_layout.add_child(diagnostic_copy)
	diagnostic_copy.pressed.connect(_copy_diagnostic_report)


func _show_ui_diagnostics() -> void:
	var lines: Array[String] = []
	lines.append("REC Utility script: LOADED")
	lines.append("Visible controls detected below. Keep REC Settings open while scanning.")
	lines.append("")
	var counts := {"LineEdit": 0, "TextEdit": 0, "BaseButton": 0, "Label": 0}
	_collect_diagnostic_controls(_scene_tree.root, lines, counts)
	lines.append("")
	lines.append("Counts: LineEdit %d | TextEdit %d | Buttons %d | Labels %d" % [counts["LineEdit"], counts["TextEdit"], counts["BaseButton"], counts["Label"]])
	if counts["LineEdit"] == 0 and counts["TextEdit"] == 0:
		lines.append("No standard text input found. REC may use a custom input control.")
	if counts["BaseButton"] == 0:
		lines.append("No standard buttons found in the visible game UI.")
	_diagnostic_text.text = "\n".join(lines)
	_diagnostic_dialog.popup_centered()


func _collect_diagnostic_controls(node: Node, lines: Array[String], counts: Dictionary) -> void:
	if node == _canvas or node == _confirm_dialog or node == _diagnostic_dialog:
		return
	if node is Control and node.is_visible_in_tree():
		var detail := ""
		if node is LineEdit:
			counts["LineEdit"] += 1
			var edit := node as LineEdit
			detail = "LineEdit | %s | placeholder=%s | text=%s" % [str(node.name), edit.placeholder_text, edit.text]
		elif node is TextEdit:
			counts["TextEdit"] += 1
			var edit := node as TextEdit
			detail = "TextEdit | %s | placeholder=%s" % [str(node.name), edit.placeholder_text]
		elif node is BaseButton:
			counts["BaseButton"] += 1
			var button := node as BaseButton
			var button_text := (node as Button).text if node is Button else ""
			detail = "%s | %s | text=%s | toggle=%s | pressed=%s" % [node.get_class(), str(node.name), button_text, str(button.toggle_mode), str(button.button_pressed)]
		elif node is Label:
			counts["Label"] += 1
			var label := node as Label
			if not label.text.strip_edges().is_empty():
				detail = "Label | %s | %s" % [str(node.name), label.text]
		if not detail.is_empty() and lines.size() < 48:
			lines.append(detail)
	for child in node.get_children():
		_collect_diagnostic_controls(child, lines, counts)


func _make_style(background: Color, border: Color, corner_radius: int = 11) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = 5.0
	style.content_margin_right = 5.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	return style


func _style_button(button: Button, background: Color, border: Color, corner_radius: int = 11) -> void:
	button.add_theme_stylebox_override("normal", _make_style(background, border, corner_radius))
	button.add_theme_stylebox_override("hover", _make_style(background.lightened(0.12), border, corner_radius))
	button.add_theme_stylebox_override("pressed", _make_style(background.darkened(0.18), border, corner_radius))
	button.add_theme_stylebox_override("focus", _make_style(background, border, corner_radius))
	button.add_theme_color_override("font_color", Color("#ffffff"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_font_size_override("font_size", 11)


func _toggle_panel() -> void:
	_panel.visible = not _panel.visible
	_reveal_launcher()


func _reveal_launcher() -> void:
	if _launcher_button == null:
		return
	_launcher_idle = 0.0
	_launcher_button.modulate.a = 1.0


func _update_launcher_fade(delta: float) -> void:
	if _launcher_button == null or not _launcher_has_been_used:
		return
	if _launcher_dragging:
		return
	_launcher_idle += delta
	var fade_progress := clampf((_launcher_idle - LAUNCHER_FADE_DELAY) / LAUNCHER_FADE_DURATION, 0.0, 1.0)
	_launcher_button.modulate.a = lerpf(1.0, LAUNCHER_IDLE_ALPHA, fade_progress)


func _clamp_launcher_position(position: Vector2) -> Vector2:
	var viewport := get_viewport().get_visible_rect().size
	var max_x := maxf(0.0, viewport.x - _launcher_button.size.x)
	var max_y := maxf(0.0, viewport.y - _launcher_button.size.y)
	return Vector2(clampf(position.x, 0.0, max_x), clampf(position.y, 0.0, max_y))


func _on_launcher_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_launcher_touch_index = touch.index
			_begin_launcher_drag(touch.position)
		else:
			if touch.index == _launcher_touch_index:
				_end_launcher_drag()
				_launcher_touch_index = -1
			_launcher_button.accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _launcher_dragging and drag.index == _launcher_touch_index:
			_move_launcher_to(drag.position)
			_launcher_button.accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_launcher_drag(get_global_mouse_position())
		else:
			_end_launcher_drag()
			_launcher_button.accept_event()
	elif event is InputEventMouseMotion and _launcher_dragging:
		_move_launcher_to(get_global_mouse_position())
		_launcher_button.accept_event()


func _begin_launcher_drag(pointer_position: Vector2) -> void:
	_launcher_has_been_used = true
	_reveal_launcher()
	_launcher_dragging = true
	_launcher_dragged = false
	_launcher_press_position = pointer_position
	_launcher_drag_offset = pointer_position - _launcher_button.global_position


func _move_launcher_to(pointer_position: Vector2) -> void:
	if not _launcher_dragging:
		return
	if pointer_position.distance_to(_launcher_press_position) > 7.0:
		_launcher_dragged = true
	_launcher_button.position = _clamp_launcher_position(pointer_position - _launcher_drag_offset)


func _end_launcher_drag() -> void:
	if not _launcher_dragging:
		return
	_launcher_dragging = false
	if _launcher_dragged:
		_launcher_button.position = _clamp_launcher_position(_launcher_button.position)
		_save_state()
	else:
		_toggle_panel()
	_reveal_launcher()



func _select_code(code: String) -> void:
	_code_input.text = code
	_code_input.grab_focus()
	_code_input.select_all()
	_set_status("Selected " + code + ". Edit, copy, or press SUBMIT.")


func _submit_code_from_field() -> void:
	var code := _code_input.text.strip_edges().to_upper()
	if code.is_empty():
		_set_status("Type or select a cheat code first.")
		return
	_pending_code = code
	if code in ADDITIVE_CODES and code in _submitted_codes:
		_confirm_dialog.dialog_text = code + " was submitted before. It may add resources again. Submit it again?"
		_confirm_dialog.popup_centered()
		return
	_submit_pending_code()


func _copy_current_code() -> void:
	var code := _code_input.text.strip_edges()
	if code.is_empty():
		_set_status("There is no code to copy yet.")
		return
	DisplayServer.clipboard_set(code)
	_set_status("Copied " + code + " to clipboard.")


func _copy_all_codes() -> void:
	var codes: Array[String] = []
	for entry in _cheats:
		codes.append(str(entry.get("code", "")))
	DisplayServer.clipboard_set("\n".join(codes))
	_set_status("Copied all " + str(codes.size()) + " cheat codes to clipboard.")


func _copy_diagnostic_report() -> void:
	if _diagnostic_text == null:
		return
	DisplayServer.clipboard_set(_diagnostic_text.text)
	_set_status("Copied the REC UI report to clipboard.")


func _request_apply_code(code: String) -> void:
	if code.is_empty():
		return
	_pending_code = code
	if code in ADDITIVE_CODES and code in _submitted_codes:
		_confirm_dialog.dialog_text = code + " was submitted before. It may add resources again. Submit it again?"
		_confirm_dialog.popup_centered()
		return
	_submit_pending_code()


func _confirm_pending_code() -> void:
	_submit_pending_code()


func _submit_pending_code() -> void:
	var input := _find_cheat_input()
	if input == null:
		_set_status("Game input not found. Your code is still here: use COPY, then paste it into REC.")
		return

	input.grab_focus()
	input.text = _pending_code
	input.text_submitted.emit(_pending_code)
	if not _submitted_codes.has(_pending_code):
		_submitted_codes.append(_pending_code)
	_save_state()
	_set_status("Submitted " + _pending_code + ". Check REC for its response.")


func _find_cheat_input() -> LineEdit:
	var all_inputs: Array[LineEdit] = []
	_collect_line_edits(_scene_tree.root, all_inputs)

	var named_matches: Array[LineEdit] = []
	for input in all_inputs:
		var description := (input.name + " " + input.placeholder_text + " " + input.tooltip_text).to_lower()
		if description.contains("cheat") or description.contains("code"):
			named_matches.append(input)

	if named_matches.size() == 1:
		return named_matches[0]
	if named_matches.size() > 1:
		return null
	if all_inputs.size() == 1:
		return all_inputs[0]
	return null


func _collect_line_edits(node: Node, result: Array[LineEdit]) -> void:
	if node is LineEdit and node.is_visible_in_tree() and not node.is_read_only():
		result.append(node as LineEdit)
	for child in node.get_children():
		_collect_line_edits(child, result)


func _toggle_shaders() -> void:
	if _shader_override:
		_shaders_enabled = not _shaders_enabled
	else:
		_shader_override = true
	_save_state()
	_update_setting_button_text()
	_apply_saved_game_settings()


func _toggle_teleport_cursor() -> void:
	if _cursor_override:
		_teleport_cursor_enabled = not _teleport_cursor_enabled
	else:
		_cursor_override = true
	_save_state()
	_update_setting_button_text()
	_apply_saved_game_settings()


func _update_setting_button_text() -> void:
	if _shader_button != null:
		var shader_state := "saved" if _shader_override else "tap to set"
		_shader_button.text = "SHADERS: " + ("ON" if _shaders_enabled else "OFF") + "  (" + shader_state + ")"
	if _cursor_button != null:
		var cursor_state := "saved" if _cursor_override else "tap to set"
		_cursor_button.text = "TELEPORT CURSOR: " + ("ON" if _teleport_cursor_enabled else "OFF") + "  (" + cursor_state + ")"


func _apply_saved_game_settings() -> void:
	if _shader_override:
		var no_shaders := _find_toggle(["no shaders", "no shader"])
		if no_shaders != null:
			var wanted_no_shaders := not _shaders_enabled
			if no_shaders.button_pressed != wanted_no_shaders:
				no_shaders.button_pressed = wanted_no_shaders
				_set_status("Applied shader preference: " + ("enabled" if _shaders_enabled else "disabled") + ".")
	if _cursor_override:
		var teleport := _find_toggle(["teleport cursor"])
		if teleport != null and teleport.button_pressed != _teleport_cursor_enabled:
			teleport.button_pressed = _teleport_cursor_enabled
			_set_status("Applied teleport cursor preference.")


func _find_toggle(tokens: Array[String]) -> BaseButton:
	var matches: Array[BaseButton] = []
	_collect_toggles(_scene_tree.root, tokens, matches)
	if matches.size() == 1:
		return matches[0]
	return null


func _collect_toggles(node: Node, tokens: Array[String], result: Array[BaseButton]) -> void:
	if node is BaseButton and node.is_visible_in_tree() and node.toggle_mode:
		var description := str(node.name)
		if node is Button:
			description += " " + (node as Button).text
		description = description.to_lower().replace("_", " ").replace("-", " ")
		for token in tokens:
			if description.contains(token):
				result.append(node as BaseButton)
				break
	for child in node.get_children():
		_collect_toggles(child, tokens, result)


func _set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message
	print("REC Utility: ", message)
