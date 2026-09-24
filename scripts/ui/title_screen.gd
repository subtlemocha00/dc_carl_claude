extends Control
## The title screen: a small keyboard menu. Up/Down choose, Enter confirms.
## - Continue is only available when the save loads. It starts the run from the saved floor
##   checkpoint (GameState.continue_from()) and opens that floor.
## - New Game starts a new run on the Surface. The Surface's checkpoint then replaces the save,
##   so if a save file exists (loadable or not) the menu asks first, with No selected.
## An unloadable save never stops the game: Continue stays unavailable, a short message says
## so, and New Game still works.

const SELECTED_COLOR := Color(1.0, 0.86, 0.35)
const NORMAL_COLOR := Color(0.9, 0.91, 0.94)
const DISABLED_COLOR := Color(0.42, 0.44, 0.5)
const ERROR_COLOR := Color(1.0, 0.5, 0.45)
const INFO_COLOR := Color(0.62, 0.65, 0.72)

enum Option { CONTINUE, NEW_GAME }

## First level of a new game.
@export_file("*.tscn") var start_scene_path: String = "res://scenes/levels/surface.tscn"

## The loaded save, or null if there is none that can be used.
var _checkpoint: FloorEntry
var _selected: Option = Option.NEW_GAME
var _confirming := false
var _confirm_yes := false

@onready var version_label: Label = %VersionLabel
@onready var continue_row: Label = %ContinueRow
@onready var new_game_row: Label = %NewGameRow
@onready var save_info_label: Label = %SaveInfoLabel
@onready var confirm_panel: Control = %ConfirmPanel
@onready var confirm_dim: Control = %ConfirmDim
@onready var confirm_question: Label = %ConfirmQuestion
@onready var no_row: Label = %NoRow
@onready var yes_row: Label = %YesRow


func _ready() -> void:
	# The game version lives in Project Settings > Application > Config > Version,
	# so it only has to be changed in one place.
	var game_version: String = ProjectSettings.get_setting("application/config/version", "dev")
	var engine_version: String = Engine.get_version_info()["string"]
	version_label.text = "Version %s  |  Godot %s" % [game_version, engine_version]
	confirm_panel.visible = false
	confirm_dim.visible = false
	_read_save()


func _unhandled_input(event: InputEvent) -> void:
	if _confirming:
		_handle_confirm_input(event)
	elif event.is_action_pressed(&"move_up", true) or event.is_action_pressed(&"move_down", true):
		get_viewport().set_input_as_handled()
		# There are only two options, and Continue can only be chosen when it is available.
		if is_continue_available():
			_selected = Option.NEW_GAME if _selected == Option.CONTINUE else Option.CONTINUE
			_refresh()
	elif event.is_action_pressed(&"ui_confirm_game"):
		get_viewport().set_input_as_handled()
		if _selected == Option.CONTINUE:
			_continue()
		elif SaveManager.has_save_file():
			_open_confirm()
		else:
			_start_new_game()


func is_continue_available() -> bool:
	return _checkpoint != null


func is_confirming() -> bool:
	return _confirming


## Loads the save to decide what the menu offers.
func _read_save() -> void:
	_checkpoint = SaveManager.load_checkpoint()
	if _checkpoint != null:
		var floor_id := FloorRegistry.get_floor_id(_checkpoint.scene_path)
		save_info_label.text = "Saved at the start of %s  -  HP %d / %d" % [
				FloorRegistry.get_display_name(floor_id), _checkpoint.carl_health, _checkpoint.carl_max_health]
		save_info_label.add_theme_color_override(&"font_color", INFO_COLOR)
		_selected = Option.CONTINUE
	else:
		var has_file := SaveManager.has_save_file()
		save_info_label.text = "Save data could not be loaded." if has_file else "No saved game yet."
		save_info_label.add_theme_color_override(&"font_color", ERROR_COLOR if has_file else INFO_COLOR)
		_selected = Option.NEW_GAME
	_refresh()


func _continue() -> void:
	# Read the save again: it may have changed since the title screen opened.
	var checkpoint := SaveManager.load_checkpoint()
	if checkpoint == null:
		_read_save()
		return
	GameState.continue_from(checkpoint)
	get_tree().change_scene_to_file(checkpoint.scene_path)


func _start_new_game() -> void:
	GameState.start_new_run()
	# The Surface saves its checkpoint when it starts, which replaces any old save.
	get_tree().change_scene_to_file(start_scene_path)


func _open_confirm() -> void:
	_confirming = true
	_confirm_yes = false
	confirm_question.text = "Start a new game?\n%s" % (
			"Existing progress will be replaced." if is_continue_available()
			else "The save that could not be loaded will be replaced.")
	confirm_panel.visible = true
	confirm_dim.visible = true
	_refresh()


func _handle_confirm_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed(&"pause_back"):
		_close_confirm()
	elif event.is_action_pressed(&"ui_confirm_game"):
		if _confirm_yes:
			_start_new_game()
		else:
			_close_confirm()
	else:
		for action: StringName in [&"move_up", &"move_down", &"move_left", &"move_right"]:
			if event.is_action_pressed(action):
				_confirm_yes = not _confirm_yes
				_refresh()


func _close_confirm() -> void:
	_confirming = false
	confirm_panel.visible = false
	confirm_dim.visible = false
	_refresh()


func _refresh() -> void:
	if is_continue_available():
		_style_row(continue_row, "Continue", _selected == Option.CONTINUE and not _confirming)
	else:
		continue_row.text = "   Continue"
		continue_row.add_theme_color_override(&"font_color", DISABLED_COLOR)
	_style_row(new_game_row, "New Game", _selected == Option.NEW_GAME and not _confirming)
	_style_row(no_row, "No", not _confirm_yes)
	_style_row(yes_row, "Yes", _confirm_yes)


func _style_row(row: Label, text: String, selected: bool) -> void:
	row.text = ("> " if selected else "   ") + text
	row.add_theme_color_override(&"font_color", SELECTED_COLOR if selected else NORMAL_COLOR)
