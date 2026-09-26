extends Node
## Autoloaded as SettingsManager (Phase 13). The player's application settings, which today
## means only the keyboard bindings of the nine gameplay controls (ControlBindings.ACTIONS):
## - the current bindings, one physical key per control, all different;
## - applying them to the InputMap, so gameplay code (which only asks for actions) follows them;
## - loading them when the game starts, before the title screen appears;
## - writing them to their own file, user://settings.json, whenever a binding changes or Reset
##   to Defaults is confirmed (never on a key press in play);
## - Reset to Defaults (ControlBindings.DEFAULT_KEYS).
##
## Settings are not run state. SaveManager's save (the checkpoint: floor, HP, items and what each
## action slot holds) never contains them, and nothing here reads or writes the save. New Game,
## Continue, Return to Title and deleting the save leave the bindings alone, and changing a
## binding never touches GameState: a slot keeps its action when its key changes.
##
## The file has its own version, independent of the save's:
##     {"settings_version": 1,
##      "keyboard": {"move_up": "I", "move_down": "K", "move_left": "J", "move_right": "L",
##                   "action_w": "1", "action_a": "2", "action_s": "3", "action_d": "4",
##                   "inventory_toggle": "Tab"}}
## Keys are stored by name (ControlBindings.get_key_name()), controls by their action name.
## "keyboard" is its own block so another kind of binding could be added beside it later.
##
## A settings file is untrusted input. Unless it is valid JSON with settings_version 1 and a
## "keyboard" block naming exactly the nine controls, each with a key a control may use
## (ControlBindings.get_key_problem()) and no key used twice, it is ignored as a whole: the
## defaults are applied, load_failed is set (the title and the Settings screen say so), and the
## file is left as it is until the next change replaces it. It never stops the game, and it
## never affects the save.
##
## Test and tool runs can never touch the player's settings (the same rule as SaveManager). A run
## started with a script as its main loop (godot -s <script>) may only use files inside
## TEST_SETTINGS_FOLDER. Such a run starts with the defaults and no file at all, unless it was
## started with the user argument --settings-file=<file inside that folder>, which it then loads
## at startup exactly as the game loads user://settings.json (tests/support/settings_child.gd).
## Anything else is refused with an error. The game itself always uses user://settings.json.

## Emitted after the bindings changed (a new binding, Reset to Defaults, or a load).
signal bindings_changed

## The settings format written by this version (unrelated to SaveManager.SAVE_VERSION).
const SETTINGS_VERSION := 1
const DEFAULT_SETTINGS_PATH := "user://settings.json"
## The only place test and tool runs may keep settings files (the tests' save folder).
const TEST_SETTINGS_FOLDER := "user://test_saves/"
## The user argument that gives a test or tool run a settings file to load at startup.
const TEST_SETTINGS_ARGUMENT := "--settings-file="
const LOAD_FAILED_MESSAGE := "Control settings could not be loaded. Defaults restored."

## Where the settings live. Tests point this at their own file under TEST_SETTINGS_FOLDER.
var settings_path: String = DEFAULT_SETTINGS_PATH
## True when the last load found a settings file it could not use and applied the defaults
## instead. Cleared by the next successful load, binding change or Reset to Defaults.
var load_failed := false
## Why the last load ignored the settings file ("" otherwise).
var last_error := ""
## True when the last change could not be written to the settings file (it still applies to
## this session).
var last_save_failed := false

var _bindings: Dictionary[StringName, Key] = {}


func _ready() -> void:
	# Autoloads are ready before the main scene is added, so the title screen and every level
	# already see the player's keys.
	var startup_path := _get_startup_settings_path()
	if startup_path.is_empty():
		_use_bindings(ControlBindings.DEFAULT_KEYS)
		return
	settings_path = startup_path
	load_settings()


## The key bound to `action` (one of ControlBindings.ACTIONS).
func get_key(action: StringName) -> Key:
	return _bindings.get(action, KEY_NONE)


## A copy of every binding (action -> key).
func get_bindings() -> Dictionary[StringName, Key]:
	return _bindings.duplicate()


## The control bound to `key`, or &"" if none is.
func find_action_for_key(key: Key) -> StringName:
	for action in ControlBindings.ACTIONS:
		if _bindings.get(action) == key:
			return action
	return &""


## True if every control has its default key.
func is_default() -> bool:
	return _bindings == ControlBindings.DEFAULT_KEYS


## Binds `action` to `key`, applies it at once and writes the settings file. Returns "" when
## `action` is now on `key`, or why nothing changed: a reserved or unusable key, or a key another
## control already uses ("Q is already assigned to Action Slot W."). A key is never taken away
## from another control, and bindings are never swapped.
func set_binding(action: StringName, key: Key) -> String:
	if action not in ControlBindings.ACTIONS:
		push_error("'%s' is not a rebindable control." % action)
		return "That control cannot be changed."
	var problem := ControlBindings.get_key_problem(key)
	if not problem.is_empty():
		return problem
	var holder := find_action_for_key(key)
	if holder == action:
		return ""
	if holder != &"":
		return "%s is already assigned to %s." % [ControlBindings.get_key_name(key), ControlBindings.get_display_name(holder)]
	var bindings := get_bindings()
	bindings[action] = key
	_use_bindings(bindings)
	load_failed = false
	save_settings()
	return ""


## Puts every control back on its default key, applies them and writes the settings file.
## Returns false if the file could not be written (the defaults still apply to this session).
func reset_to_defaults() -> bool:
	_use_bindings(ControlBindings.DEFAULT_KEYS)
	load_failed = false
	return save_settings()


## Reads settings_path and applies what it holds. With no file, or a file that cannot be used,
## the defaults apply. Returns false (with the reason in last_error, and load_failed set) only
## when a file existed but could not be used.
func load_settings() -> bool:
	last_error = ""
	load_failed = false
	if not _check_settings_path_allowed():
		_use_bindings(ControlBindings.DEFAULT_KEYS)
		return false
	var path := _find_file_to_load()
	if path.is_empty():
		_use_bindings(ControlBindings.DEFAULT_KEYS)
		return true
	var bindings := _read_file(path)
	_use_bindings(ControlBindings.DEFAULT_KEYS if bindings.is_empty() else bindings)
	load_failed = bindings.is_empty()
	return not load_failed


## Writes the current bindings to settings_path, replacing the old file only once the new one is
## complete and checked. Returns false (the old file stays as it was) if it could not.
func save_settings() -> bool:
	last_save_failed = true
	if not _check_settings_path_allowed():
		return false
	var text := JSON.stringify(encode(), "\t")
	# The same safe write as the save: a temporary file, read back and compared, then renamed
	# over the old one. If the game stops part-way, the old settings are still intact.
	var temp_path := _get_temp_path()
	DirAccess.make_dir_recursive_absolute(settings_path.get_base_dir())
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write the settings file %s: %s." % [temp_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(text)
	var write_error := file.get_error()
	file.close()
	if write_error != OK or FileAccess.get_file_as_string(temp_path) != text:
		push_error("Could not write the settings file %s." % temp_path)
		return false
	var rename_error := DirAccess.rename_absolute(temp_path, settings_path)
	if rename_error != OK:
		push_error("Could not replace the settings file %s: %s." % [settings_path, error_string(rename_error)])
		return false
	last_save_failed = false
	return true


## Deletes the settings file (and any unfinished temporary file). The bindings in use do not
## change. Does nothing if there is none.
func delete_settings_file() -> void:
	if not _check_settings_path_allowed():
		return
	for path in [settings_path, _get_temp_path()]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## True if a settings file exists, usable or not. (Always false for a file this run may not use.)
func has_settings_file() -> bool:
	return _check_settings_path_allowed() and not _find_file_to_load().is_empty()


## True if this run may read and write `path`: always in the game, and only files inside
## TEST_SETTINGS_FOLDER in a test or tool run (see the class description).
func is_settings_path_allowed(path: String) -> bool:
	if not _is_test_or_tool_run():
		return true
	return path.simplify_path().begins_with(TEST_SETTINGS_FOLDER)


## The settings data for the current bindings.
func encode() -> Dictionary:
	var keyboard := {}
	for action in ControlBindings.ACTIONS:
		keyboard[String(action)] = ControlBindings.get_key_name(get_key(action))
	return {"settings_version": SETTINGS_VERSION, "keyboard": keyboard}


## The bindings in settings data, or {} (with the reason in last_error) if the data cannot be
## used. `data` itself is never changed.
func decode(data: Variant) -> Dictionary[StringName, Key]:
	if not data is Dictionary:
		return _reject("the settings are not a JSON object")
	for field: Variant in data:
		if field not in ["settings_version", "keyboard"]:
			return _reject("unknown setting %s" % JSON.stringify(field))
	var version: Variant = data.get("settings_version")
	if not (version is int or (version is float and is_finite(version) and version == floorf(version))):
		return _reject("settings_version is missing or not a whole number")
	if int(version) != SETTINGS_VERSION:
		return _reject("settings_version %d is not supported (this game reads version %d)" % [int(version), SETTINGS_VERSION])
	var keyboard: Variant = data.get("keyboard")
	if not keyboard is Dictionary:
		return _reject("keyboard is missing or not an object")
	for action: Variant in keyboard:
		if not action is String or StringName(action) not in ControlBindings.ACTIONS:
			return _reject("keyboard names an unknown control %s" % JSON.stringify(action))
	var bindings: Dictionary[StringName, Key] = {}
	for action in ControlBindings.ACTIONS:
		if not keyboard.has(String(action)):
			return _reject("keyboard has no key for %s" % action)
		var key_name: Variant = keyboard[String(action)]
		var key := ControlBindings.get_key_from_name(key_name) if key_name is String else KEY_NONE
		if key == KEY_NONE:
			return _reject("the key %s for %s is not a key" % [JSON.stringify(key_name), action])
		var problem := ControlBindings.get_key_problem(key)
		if not problem.is_empty():
			return _reject("the key for %s cannot be used: %s" % [action, problem])
		var holder: Variant = bindings.find_key(key)
		if holder != null:
			return _reject("%s is bound to both %s and %s" % [key_name, holder, action])
		bindings[action] = key
	return bindings


## Makes `bindings` the current ones and puts each control's key in the InputMap: its keyboard
## event is replaced, anything else bound to the action (nothing yet) is kept. A control whose
## key changed counts as released until its new key is pressed again, so the key press that
## chose a binding never also triggers it.
func _use_bindings(bindings: Dictionary[StringName, Key]) -> void:
	var changed := bindings != _bindings
	_bindings = bindings.duplicate()
	for action in ControlBindings.ACTIONS:
		var key: Key = _bindings[action]
		if ControlBindings.get_key(action) == key:
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				InputMap.action_erase_event(action, event)
		var key_event := InputEventKey.new()
		key_event.physical_keycode = key
		InputMap.action_add_event(action, key_event)
		Input.action_release(action)
	if changed:
		bindings_changed.emit()
		if is_inside_tree():
			get_tree().call_group(ControlBindings.HINT_GROUP, &"refresh_control_hints")


func _read_file(path: String) -> Dictionary[StringName, Key]:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return _reject("the settings file is empty or unreadable")
	var json := JSON.new()
	if json.parse(text) != OK:
		return _reject("the settings file is not valid JSON (line %d: %s)" % [json.get_error_line(), json.get_error_message()])
	return decode(json.data)


## The settings file a run starts with: user://settings.json in the game; in a test or tool run
## only the file given with TEST_SETTINGS_ARGUMENT, or "" for none (the defaults, no file).
func _get_startup_settings_path() -> String:
	if not _is_test_or_tool_run():
		return DEFAULT_SETTINGS_PATH
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(TEST_SETTINGS_ARGUMENT):
			return argument.trim_prefix(TEST_SETTINGS_ARGUMENT)
	return ""


## The file load_settings() reads: the settings, or else a finished temporary file left behind
## if the game stopped between writing it and renaming it. "" if there is neither.
func _find_file_to_load() -> String:
	for path in [settings_path, _get_temp_path()]:
		if FileAccess.file_exists(path):
			return path
	return ""


func _get_temp_path() -> String:
	return settings_path + ".tmp"


## A run started with a script as its main loop (every test, and tool scripts). The main loop
## has a script only then. (It also works before this node has entered the tree.)
func _is_test_or_tool_run() -> bool:
	return Engine.get_main_loop().get_script() != null


## Reports an error and returns false if this run may not use settings_path. Every read, write
## and delete goes through here first.
func _check_settings_path_allowed() -> bool:
	if is_settings_path_allowed(settings_path):
		return true
	push_error("SettingsManager refused to use %s: a test or tool run may only use settings files inside %s. Set SettingsManager.settings_path first." % [settings_path, TEST_SETTINGS_FOLDER])
	return false


func _reject(reason: String) -> Dictionary[StringName, Key]:
	last_error = reason
	var none: Dictionary[StringName, Key] = {}
	return none
