extends CanvasLayer
## The pause menu (Phase 10), opened with Escape during play. While it is open the game is
## paused, exactly as it is while the action menu is open: the scene tree is paused, so Carl,
## Donut, the enemies, projectiles, knockback, cooldowns and Donut's recovery countdown all stop
## (they count physics ticks), and stairs and pickups cannot trigger.
## - Up/Down choose Resume, Return to Title or Quit Game; Enter confirms; Escape resumes.
## - Resume closes the menu and the game carries on where it was.
## - Return to Title and Quit Game each ask first ("Progress since entering this floor will be
##   lost."), with No selected. Up/Down (or Left/Right) choose, Enter confirms, Escape means No.
##   No goes back to the pause menu, still paused.
## - Yes emits return_to_title_requested or quit_requested. The level does the rest. Neither
##   saves anything: the save keeps the checkpoint written when Carl entered the floor.
## The menu has no gameplay rules and never touches GameState or the save.
##
## Input notes (the same rules as the action menu):
## - It runs while the game is paused (process_mode Always), but only opens while the game is
##   not paused. So it never opens over the action menu or GAME OVER, and the action menu (which
##   has the same rule) never opens over it: only one of them can be open at a time.
## - While open it takes every key press, so none of them reach the game or the action menu.
##   One key press therefore never both closes one menu and opens another. Carl also ignores
##   keys that are still held when the game carries on (see carl.gd).
## - Its rows are Labels, which never take keyboard focus, so Godot's built-in ui_accept and
##   ui_cancel actions (Enter, Space, Escape) cannot press anything in it.

## Emitted when the player confirms Return to Title.
signal return_to_title_requested
## Emitted when the player confirms Quit Game.
signal quit_requested

enum Option { RESUME, RETURN_TO_TITLE, QUIT }

const SELECTED_COLOR := Color(1.0, 0.86, 0.35)
const NORMAL_COLOR := Color(0.9, 0.91, 0.94)
const LOST_PROGRESS_WARNING := "Progress since entering this floor will be lost."

var _selected: Option = Option.RESUME
## True while the Yes/No question for the selected option is shown.
var _confirming := false
var _confirm_yes := false
## Set once Yes was chosen: the level is leaving (or the game is quitting), so any further
## key press is ignored.
var _leaving := false

@onready var menu_panel: Control = %MenuPanel
@onready var option_rows: Array[Label] = [%ResumeRow, %ReturnToTitleRow, %QuitRow]
@onready var confirm_panel: Control = %ConfirmPanel
@onready var confirm_question: Label = %ConfirmQuestion
@onready var no_row: Label = %NoRow
@onready var yes_row: Label = %YesRow


func _ready() -> void:
	visible = false
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		if event.is_action_pressed(&"pause_back") and not get_tree().paused:
			get_viewport().set_input_as_handled()
			open()
		return

	# While open, the pause menu takes every key press, so none of them reach the game.
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
	if _leaving:
		return
	if _confirming:
		_handle_confirm_input(event)
	elif event.is_action_pressed(&"pause_back"):
		resume()
	elif event.is_action_pressed(&"move_up", true):
		_select(wrapi(_selected - 1, 0, Option.size()))
	elif event.is_action_pressed(&"move_down", true):
		_select(wrapi(_selected + 1, 0, Option.size()))
	elif event.is_action_pressed(&"ui_confirm_game"):
		_choose(_selected)


func is_open() -> bool:
	return visible


func is_confirming() -> bool:
	return _confirming


## The highlighted option.
func get_selected_option() -> Option:
	return _selected


## Whether Yes (true) or No (false) is highlighted in the question.
func is_yes_selected() -> bool:
	return _confirm_yes


## Pauses the game and shows the menu with Resume selected. Does nothing if the game is
## already paused (the action menu or GAME OVER is up).
func open() -> void:
	if is_open() or get_tree().paused:
		return
	get_tree().paused = true
	_selected = Option.RESUME
	_confirming = false
	visible = true
	_refresh()


## Hides the menu and lets the game carry on from where it was.
func resume() -> void:
	if not is_open() or _leaving:
		return
	_confirming = false
	visible = false
	get_tree().paused = false


func _select(option: Option) -> void:
	_selected = option
	_refresh()


func _choose(option: Option) -> void:
	match option:
		Option.RESUME:
			resume()
		Option.RETURN_TO_TITLE:
			_open_confirm("Return to title?")
		Option.QUIT:
			_open_confirm("Quit game?")


func _open_confirm(question: String) -> void:
	_confirming = true
	_confirm_yes = false
	confirm_question.text = "%s\n%s" % [question, LOST_PROGRESS_WARNING]
	_refresh()


func _handle_confirm_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause_back"):
		_close_confirm()
	elif event.is_action_pressed(&"ui_confirm_game"):
		if not _confirm_yes:
			_close_confirm()
			return
		_leaving = true
		if _selected == Option.RETURN_TO_TITLE:
			return_to_title_requested.emit()
		else:
			quit_requested.emit()
	else:
		for action: StringName in [&"move_up", &"move_down", &"move_left", &"move_right"]:
			if event.is_action_pressed(action, true):
				_confirm_yes = not _confirm_yes
				_refresh()
				return


## Back to the pause menu, still paused, with the same option selected.
func _close_confirm() -> void:
	_confirming = false
	_refresh()


func _refresh() -> void:
	menu_panel.visible = not _confirming
	confirm_panel.visible = _confirming
	for option: int in option_rows.size():
		_style_row(option_rows[option], _option_text(option), option == _selected)
	_style_row(no_row, "No", not _confirm_yes)
	_style_row(yes_row, "Yes", _confirm_yes)


func _option_text(option: Option) -> String:
	match option:
		Option.RETURN_TO_TITLE:
			return "Return to Title"
		Option.QUIT:
			return "Quit Game"
	return "Resume"


func _style_row(row: Label, text: String, selected: bool) -> void:
	row.text = ("> " if selected else "   ") + text
	row.add_theme_color_override(&"font_color", SELECTED_COLOR if selected else NORMAL_COLOR)
