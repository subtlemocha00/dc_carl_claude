extends Control
## The Settings screen (Phase 13), shared by the title screen and the pause menu: each has one as
## a child and opens it from its Settings row. It has one section, Controls: the nine gameplay
## controls (ControlBindings.ACTIONS) with their current keys, then Reset to Defaults and Back.
## - Up/Down choose a row, Enter changes it, Escape (or Back) closes the screen (closed is
##   emitted and the menu underneath carries on).
## - Enter on a control waits for a key ("Press a key for Action Slot W"). The next key press
##   becomes that control's key through SettingsManager.set_binding(), which also applies and
##   saves it. Escape cancels, changing nothing. A key that is reserved (Escape, Enter), unusable
##   (Shift on its own, ...) or already used by another control is refused with a message, and
##   nothing changes: no control ever loses its key to another, and nothing is swapped.
## - Reset to Defaults asks first ("Reset all controls to defaults?", No selected).
## The screen never touches GameState or the save: slot contents are run state, keys are
## settings.
##
## Input notes (the menus' rules):
## - It runs while the game is paused (process_mode Always): from the pause menu the game stays
##   paused underneath the whole time.
## - While open it takes every key press, so none reaches the menu underneath, the game or the
##   action menu. Its own keys are the fixed menu keys (menu_up, menu_down, ui_confirm_game,
##   pause_back), never the gameplay controls it edits, so it always stays usable.
## - The key press that chose a binding is used up: its key repeat and its release are ignored,
##   so it never also moves the selection. (Carl, paused underneath, ignores it too: the action
##   counts as released until its new key is pressed again, see SettingsManager._use_bindings().)

## Emitted when the screen closes (Escape or Back).
signal closed

const SELECTED_COLOR := Color(1.0, 0.86, 0.35)
const NORMAL_COLOR := Color(0.9, 0.91, 0.94)
const KEY_COLOR := Color(0.62, 0.8, 1.0)
const WAITING_COLOR := Color(1.0, 0.62, 0.3)
const INFO_COLOR := Color(0.75, 0.77, 0.82)
const ERROR_COLOR := Color(1.0, 0.5, 0.45)
const ROW_FONT_SIZE := 22
const RESET_ROW_TEXT := "Reset to Defaults"
const BACK_ROW_TEXT := "Back"

## The highlighted row: 0 to 8 are the controls, then Reset to Defaults, then Back.
var _selected := 0
## The control waiting for its new key, or &"" when not waiting.
var _capturing: StringName = &""
var _confirming_reset := false
var _confirm_yes := false
## A key whose press was used up choosing a binding: its repeats and its release are ignored.
var _used_key: Key = KEY_NONE
var _message := ""
var _message_is_error := false
## One row per control: [name Label, key Label].
var _control_rows: Array[Array] = []

@onready var rows: VBoxContainer = %Rows
@onready var reset_row: Label = %ResetRow
@onready var back_row: Label = %BackRow
@onready var message_label: Label = %MessageLabel
@onready var menu_panel: Control = %SettingsPanel
@onready var confirm_panel: Control = %ResetConfirmPanel
@onready var no_row: Label = %ResetNoRow
@onready var yes_row: Label = %ResetYesRow


func _ready() -> void:
	visible = false
	for i in ControlBindings.ACTIONS.size():
		var row := HBoxContainer.new()
		row.name = "%sRow" % String(ControlBindings.ACTIONS[i]).to_pascal_case()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_label := _new_row_label(260)
		var key_label := _new_row_label(150)
		row.add_child(name_label)
		row.add_child(key_label)
		rows.add_child(row)
		rows.move_child(row, i)
		_control_rows.append([name_label, key_label])
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or not event is InputEventKey:
		return
	# While open, the screen takes every key press, so none reaches anything underneath.
	get_viewport().set_input_as_handled()
	var key_event := event as InputEventKey
	var key := ControlBindings.get_event_key(key_event)
	if _used_key != KEY_NONE and key == _used_key:
		if not key_event.pressed:
			_used_key = KEY_NONE
		return
	if _capturing != &"":
		if key_event.pressed and not key_event.echo:
			_capture(key_event)
	elif _confirming_reset:
		_handle_confirm_input(key_event)
	elif event.is_action_pressed(&"pause_back"):
		close()
	elif event.is_action_pressed(&"menu_up", true):
		_select(wrapi(_selected - 1, 0, _get_row_count()))
	elif event.is_action_pressed(&"menu_down", true):
		_select(wrapi(_selected + 1, 0, _get_row_count()))
	elif event.is_action_pressed(&"ui_confirm_game"):
		_choose()


## Shows the screen with the first control selected.
func open() -> void:
	_selected = 0
	_capturing = &""
	_confirming_reset = false
	_used_key = KEY_NONE
	_set_message(SettingsManager.LOAD_FAILED_MESSAGE if SettingsManager.load_failed else "", SettingsManager.load_failed)
	visible = true
	_refresh()


## Hides the screen and emits closed.
func close() -> void:
	if not is_open():
		return
	visible = false
	_capturing = &""
	_confirming_reset = false
	closed.emit()


func is_open() -> bool:
	return visible


## The control waiting for a key, or &"" when not waiting.
func get_capturing_action() -> StringName:
	return _capturing


func is_confirming_reset() -> bool:
	return _confirming_reset


## Whether Yes (true) or No (false) is highlighted in the Reset to Defaults question.
func is_yes_selected() -> bool:
	return _confirm_yes


func get_selected_row() -> int:
	return _selected


## The text of the message line ("" when there is none).
func get_message() -> String:
	return _message


func _get_row_count() -> int:
	return ControlBindings.ACTIONS.size() + 2


func _select(row: int) -> void:
	_selected = row
	_refresh()


func _choose() -> void:
	if _selected < ControlBindings.ACTIONS.size():
		_capturing = ControlBindings.ACTIONS[_selected]
		_set_message("Press a key for %s   (Esc: cancel)" % ControlBindings.get_display_name(_capturing), false)
	elif _selected == ControlBindings.ACTIONS.size():
		_confirming_reset = true
		_confirm_yes = false
	else:
		close()
		return
	_refresh()


func _capture(event: InputEventKey) -> void:
	var action := _capturing
	var key := ControlBindings.get_event_key(event)
	_capturing = &""
	_used_key = key
	if event.is_action_pressed(&"pause_back"):
		_set_message("Nothing changed.", false)
	else:
		var problem := SettingsManager.set_binding(action, key)
		if not problem.is_empty():
			_set_message(problem, true)
		elif SettingsManager.last_save_failed:
			_set_message("%s is now %s, but the settings could not be saved." % [
					ControlBindings.get_display_name(action), ControlBindings.get_key_label(action)], true)
		else:
			_set_message("%s is now %s." % [ControlBindings.get_display_name(action), ControlBindings.get_key_label(action)], false)
	_refresh()


func _handle_confirm_input(event: InputEventKey) -> void:
	if event.is_action_pressed(&"pause_back"):
		_confirming_reset = false
	elif event.is_action_pressed(&"ui_confirm_game"):
		_confirming_reset = false
		if _confirm_yes:
			if SettingsManager.reset_to_defaults():
				_set_message("All controls are back to their defaults.", false)
			else:
				_set_message("All controls are back to their defaults, but the settings could not be saved.", true)
	else:
		for action: StringName in [&"menu_up", &"menu_down", &"menu_left", &"menu_right"]:
			if event.is_action_pressed(action, true):
				_confirm_yes = not _confirm_yes
				break
	_refresh()


func _set_message(text: String, is_error: bool) -> void:
	_message = text
	_message_is_error = is_error


func _refresh() -> void:
	menu_panel.visible = not _confirming_reset
	confirm_panel.visible = _confirming_reset
	for i in _control_rows.size():
		var action := ControlBindings.ACTIONS[i]
		var selected := i == _selected
		var name_label: Label = _control_rows[i][0]
		var key_label: Label = _control_rows[i][1]
		name_label.text = ("> " if selected else "   ") + ControlBindings.get_display_name(action)
		name_label.add_theme_color_override(&"font_color", SELECTED_COLOR if selected else NORMAL_COLOR)
		var waiting := action == _capturing
		key_label.text = "..." if waiting else ControlBindings.get_key_label(action)
		key_label.add_theme_color_override(&"font_color", WAITING_COLOR if waiting else KEY_COLOR)
	_style_row(reset_row, RESET_ROW_TEXT, _selected == ControlBindings.ACTIONS.size())
	_style_row(back_row, BACK_ROW_TEXT, _selected == ControlBindings.ACTIONS.size() + 1)
	_style_row(no_row, "No", not _confirm_yes)
	_style_row(yes_row, "Yes", _confirm_yes)
	message_label.text = _message
	message_label.add_theme_color_override(&"font_color", ERROR_COLOR if _message_is_error else INFO_COLOR)


func _style_row(row: Label, text: String, selected: bool) -> void:
	row.text = ("> " if selected else "   ") + text
	row.add_theme_color_override(&"font_color", SELECTED_COLOR if selected else NORMAL_COLOR)


func _new_row_label(width: float) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(width, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", ROW_FONT_SIZE)
	return label
