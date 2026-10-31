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
var _panel: PanelContainer
var _status_label: Label
var _shader_button: Button
var _cursor_button: Button
var _confirm_dialog: ConfirmationDialog
var _pending_code := ""
var _scan_elapsed := 0.0


func initialize(mod_path: String, scene_tree: SceneTree) -> void:
	_mod_path = mod_path
	_scene_tree = scene_tree
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_state()
	_load_cheats()
	_scene_tree.root.call_deferred("add_child", self)


func _ready() -> void:
	_build_interface()
	print("REC Utility: loaded ", _cheats.size(), " cheat codes")


func _process(delta: float) -> void:
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


func _save_state() -> void:
	var config := ConfigFile.new()
	config.set_value("shader", "override", _shader_override)
	config.set_value("shader", "enabled", _shaders_enabled)
	config.set_value("cursor", "override", _cursor_override)
	config.set_value("cursor", "enabled", _teleport_cursor_enabled)
	config.set_value("history", "submitted", _submitted_codes)
	var error := config.save(STATE_PATH)
	if error != OK:
		push_warning("REC Utility: could not save preferences")


func _build_interface() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 120
	add_child(_canvas)

	var viewport := get_viewport().get_visible_rect().size

	var open_button := Button.new()
	open_button.text = "REC+"
	open_button.position = Vector2(maxf(8.0, viewport.x - 88.0), maxf(8.0, viewport.y - 76.0))
	open_button.custom_minimum_size = Vector2(76.0, 56.0)
	_style_button(open_button, Color("#26344a"), Color("#78c8b5"))
	_canvas.add_child(open_button)
	open_button.pressed.connect(_toggle_panel)

	var panel_width := minf(440.0, viewport.x - 20.0)
	var panel_height := minf(590.0, viewport.y - 32.0)
	_panel = PanelContainer.new()
	_panel.position = Vector2((viewport.x - panel_width) / 2.0, (viewport.y - panel_height) / 2.0)
	_panel.size = Vector2(panel_width, panel_height)
	_panel.visible = false
	_panel.add_theme_stylebox_override("panel", _make_style(Color("#172333"), Color("#78c8b5")))
	_canvas.add_child(_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	_panel.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)

	var title := Label.new()
	title.text = "REC UTILITY"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color("#f3e6bd"))
	title.add_theme_font_size_override("font_size", 20)
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(48.0, 44.0)
	_style_button(close_button, Color("#5b3545"), Color("#f3e6bd"))
	header.add_child(close_button)
	close_button.pressed.connect(func() -> void: _panel.visible = false)

	_shader_button = Button.new()
	_shader_button.custom_minimum_size = Vector2(0.0, 48.0)
	_style_button(_shader_button, Color("#26344a"), Color("#78c8b5"))
	layout.add_child(_shader_button)
	_shader_button.pressed.connect(_toggle_shaders)

	_cursor_button = Button.new()
	_cursor_button.custom_minimum_size = Vector2(0.0, 48.0)
	_style_button(_cursor_button, Color("#26344a"), Color("#78c8b5"))
	layout.add_child(_cursor_button)
	_cursor_button.pressed.connect(_toggle_teleport_cursor)
	_update_setting_button_text()

	var divider := HSeparator.new()
	layout.add_child(divider)

	var section_title := Label.new()
	section_title.text = "CHEAT CODES  /  TAP TO SUBMIT"
	section_title.add_theme_color_override("font_color", Color("#f3e6bd"))
	layout.add_child(section_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0.0, maxf(120.0, panel_height - 250.0))
	layout.add_child(scroll)

	var cheat_list := VBoxContainer.new()
	cheat_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cheat_list.add_theme_constant_override("separation", 4)
	scroll.add_child(cheat_list)

	for entry in _cheats:
		var row := HBoxContainer.new()
		cheat_list.add_child(row)

		var code_button := Button.new()
		code_button.text = str(entry.get("code", "UNKNOWN"))
		code_button.custom_minimum_size = Vector2(132.0, 48.0)
		_style_button(code_button, Color("#34435b"), Color("#f3e6bd"))
		row.add_child(code_button)
		code_button.pressed.connect(_request_apply_code.bind(str(entry.get("code", ""))))

		var description := Label.new()
		description.text = str(entry.get("description", ""))
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_color_override("font_color", Color("#d6e0e8"))
		description.add_theme_font_size_override("font_size", 13)
		row.add_child(description)

	_status_label = Label.new()
	_status_label.text = "Open REC Settings and keep the cheat box visible."
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(0.0, 42.0)
	_status_label.add_theme_color_override("font_color", Color("#f3e6bd"))
	layout.add_child(_status_label)

	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "Repeat cheat?"
	_confirm_dialog.dialog_text = "This code may add resources again. Do you want to submit it again?"
	add_child(_confirm_dialog)
	_confirm_dialog.confirmed.connect(_confirm_pending_code)


func _make_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _style_button(button: Button, background: Color, border: Color) -> void:
	button.add_theme_stylebox_override("normal", _make_style(background, border))
	button.add_theme_stylebox_override("hover", _make_style(background.lightened(0.12), border))
	button.add_theme_stylebox_override("pressed", _make_style(background.darkened(0.18), border))
	button.add_theme_stylebox_override("focus", _make_style(background, border))
	button.add_theme_color_override("font_color", Color("#ffffff"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_font_size_override("font_size", 15)


func _toggle_panel() -> void:
	_panel.visible = not _panel.visible


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
		_set_status("Cheat box not found. Open REC Settings and leave its cheat input visible.")
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
