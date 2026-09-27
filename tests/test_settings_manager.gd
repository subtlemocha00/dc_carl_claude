extends "res://tests/support/game_test.gd"
## Phase 13 (settings format 2 and Interact: Phase 14): SettingsManager, the persistent keyboard
## bindings, on this test's own settings file (user://test_saves/test_settings_manager_settings.json)
## and its own save file.
## - Defaults: no settings file gives the ten canonical bindings (Up/Down/Left/Right, W/A/S/D,
##   Space, E for Interact), each the only key event of its InputMap action, and the menus' fixed
##   keys.
## - Changing a binding: applied to the InputMap at once (the old key no longer triggers the action,
##   the new one does), written to the settings file (settings_version 2, stable action ids and key
##   names, nothing else), and a key held when its binding changes counts as released.
## - Refused bindings, each leaving every binding and the file exactly as they were: a key another
##   control uses (with the message naming it, across movement, slots, Inventory and Interact),
##   Escape and Enter (reserved), modifiers on their own, lock, function and media keys.
## - Loading: a valid file is applied; no file gives the defaults; a finished temporary file left by
##   an interrupted write is used. 33 kinds of bad files (truncated or empty JSON, unsupported
##   versions such as 3, duplicate keys, a missing or unknown control, Interact missing from a
##   version 2 file or named in a version 1 file, Escape or Enter, unknown key names, wrong types,
##   extra fields) each give the defaults with load_failed set, and leave the file untouched; the
##   next change replaces it.
## - Migration (Phase 14): the two real Phase 13 files (tests/fixtures/phase13_settings_v1_*.json,
##   written by the Phase 13 game) keep their nine keys; Interact gets E when E is free, and R when
##   E and F are taken (the fallback order E, F, R, T, G, Y, H, U, V, B, N, M, 5-9, 0); the file is
##   then rewritten as version 2 (the safe write, no temporary file left) and the next load reads it
##   as it is. E on movement gives F; the first nine fallback keys all taken gives B; the result is
##   always ten different keys, and the same every time. Invalid version 1 files give the defaults
##   and are left untouched. A failed write-back still applies the migrated keys for the session and
##   leaves the version 1 file as it was. A leftover version 1 temporary file is migrated too. With no
##   fallback key free (impossible from a real file) the migration gives up, and nothing is applied.
##   The save file is never touched.
## - Safe write: a write that cannot complete leaves the old file as it was.
## - Reset to Defaults restores and writes the ten defaults.
## - Independence from the save: changing, resetting and loading settings never touch the save
##   file, GameState's slots or inventory; New Game, end of run and deleting the save never touch
##   the settings. The save format is still 3 and holds no bindings; the settings file holds no run.
## - Isolation: a test run may not use the player's settings file (user://settings.json), directly
##   or through the test folder; every attempt is refused with an error and touches nothing.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_settings_manager.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const V1_CUSTOM_FIXTURE := "res://tests/fixtures/phase13_settings_v1_custom.json"
const V1_E_TAKEN_FIXTURE := "res://tests/fixtures/phase13_settings_v1_e_taken.json"
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const SLINGSHOT: ActionDefinition = preload("res://resources/actions/slingshot.tres")
const FLOOR_6_PATH := "res://scenes/levels/floor_06.tscn"
const DEFAULT_LABELS := {
	&"move_up": "Up", &"move_down": "Down", &"move_left": "Left", &"move_right": "Right",
	&"action_w": "W", &"action_a": "A", &"action_s": "S", &"action_d": "D", &"inventory_toggle": "Space",
	&"interact": "E",
}
## A valid version 2 keyboard block.
const CUSTOM_KEYBOARD := {
	"move_up": "I", "move_down": "K", "move_left": "J", "move_right": "L",
	"action_w": "1", "action_a": "2", "action_s": "3", "action_d": "4", "inventory_toggle": "Tab",
	"interact": "F",
}
## A valid version 1 (Phase 13) keyboard block: the nine controls it knew.
const V1_KEYBOARD := {
	"move_up": "I", "move_down": "K", "move_left": "J", "move_right": "L",
	"action_w": "1", "action_a": "2", "action_s": "3", "action_d": "4", "inventory_toggle": "Tab",
}


## Counts refresh_control_hints() calls, like every node that shows key names.
class HintCounter extends Node:
	var refreshes := 0

	func _ready() -> void:
		add_to_group(ControlBindings.HINT_GROUP)

	func refresh_control_hints() -> void:
		refreshes += 1


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	_check_defaults()
	_check_isolation()
	_check_set_binding()
	_check_refused_bindings()
	_check_loading()
	_check_bad_files()
	_check_migration()
	_check_safe_write()
	_check_reset()
	_check_independence_from_the_save()
	finish()


func _manager() -> Node:
	return settings_manager()


func _check_defaults() -> void:
	print("-- Defaults")
	var manager := _manager()
	check(manager.SETTINGS_VERSION == 2, "the settings format is version 2")
	check(manager.DEFAULT_SETTINGS_PATH == "user://settings.json" and manager.DEFAULT_SETTINGS_PATH != save_manager().DEFAULT_SAVE_PATH,
			"the player's settings are user://settings.json, a file of their own beside the save")
	check(not FileAccess.file_exists(manager.settings_path), "this test starts with no settings file", manager.settings_path)
	check(ControlBindings.ACTIONS.size() == 10 and ControlBindings.ACTIONS[9] == &"interact", "ten controls can be rebound, the tenth Interact",
			str(ControlBindings.ACTIONS))
	for action in ControlBindings.ACTIONS:
		var events := InputMap.action_get_events(action)
		check(events.size() == 1 and ControlBindings.get_key(action) == ControlBindings.DEFAULT_KEYS[action]
				and manager.get_key(action) == ControlBindings.DEFAULT_KEYS[action] and ControlBindings.get_key_label(action) == DEFAULT_LABELS[action],
				"%s defaults to %s" % [ControlBindings.get_display_name(action), DEFAULT_LABELS[action]], "%d events, %s" % [events.size(), ControlBindings.get_key_label(action)])
	check(manager.is_default() and not manager.load_failed, "no settings file: the canonical defaults, and nothing went wrong")
	for fixed: Array in [[&"menu_up", KEY_UP], [&"menu_down", KEY_DOWN], [&"menu_left", KEY_LEFT], [&"menu_right", KEY_RIGHT],
			[&"ui_confirm_game", KEY_ENTER], [&"pause_back", KEY_ESCAPE]]:
		check(ControlBindings.get_key(fixed[0]) == fixed[1] and fixed[0] not in ControlBindings.ACTIONS,
				"%s stays on %s and cannot be rebound" % [fixed[0], ControlBindings.get_key_name(fixed[1])])


func _check_isolation() -> void:
	print("-- A test run can never use the player's settings")
	var manager := _manager()
	var own_path: String = manager.settings_path
	check(own_path == TEST_SAVE_FOLDER + "test_settings_manager_settings.json" and manager.is_settings_path_allowed(own_path),
			"this test uses its own file in the test folder", own_path)
	check(not manager.is_settings_path_allowed(manager.DEFAULT_SETTINGS_PATH), "user://settings.json is refused")
	check(not manager.is_settings_path_allowed("user://test_saves/../settings.json"), "user://test_saves/../settings.json is refused")
	check(not manager.is_settings_path_allowed("user://test_saves_old/settings.json"), "user://test_saves_old/settings.json is refused")
	# A stray file outside the test folder proves refusals touch nothing, before the real path is tried.
	var stray_path := "user://test_settings_stray.json"
	var stray := FileAccess.open(stray_path, FileAccess.WRITE)
	stray.store_string("stray")
	stray.close()
	for path: String in [stray_path, manager.DEFAULT_SETTINGS_PATH]:
		var existed := FileAccess.file_exists(path)
		var modified_time := FileAccess.get_modified_time(path) if existed else 0
		manager.settings_path = path
		check(not manager.has_settings_file(), "%s: has_settings_file() is refused" % path)
		check(manager.set_binding(&"action_w", KEY_Q) == "" and not manager.save_settings(), "%s: nothing is written" % path)
		check(not manager.load_settings() and manager.is_default(), "%s: nothing is loaded (the defaults apply)" % path)
		manager.delete_settings_file()
		var messages := take_engine_messages()
		check(messages.size() >= 4 and Array(messages).all(func(text: String) -> bool: return text.contains("SettingsManager refused to use")),
				"%s: each attempt is refused with an error" % path, str(messages))
		check(FileAccess.file_exists(path) == existed and (not existed or FileAccess.get_modified_time(path) == modified_time),
				"%s: the file is exactly as it was" % path)
	check(FileAccess.get_file_as_string(stray_path) == "stray", "the stray file was neither written nor deleted")
	DirAccess.remove_absolute(stray_path)
	manager.settings_path = own_path
	manager.reset_to_defaults()
	manager.delete_settings_file()


func _check_set_binding() -> void:
	print("-- Changing a binding")
	var manager := _manager()
	var counter := HintCounter.new()
	root.add_child(counter)
	var signal_count := [0]
	var on_changed := func() -> void: signal_count[0] += 1
	manager.bindings_changed.connect(on_changed)
	# A held W: after Action Slot W moves to Q, the action counts as released.
	send_key(KEY_W, true)
	check(Input.is_action_pressed(&"action_w"), "W held: action_w is pressed")
	check(manager.set_binding(&"action_w", KEY_Q) == "", "Action Slot W can be bound to Q")
	check(not Input.is_action_pressed(&"action_w"), "the held W no longer counts as action_w once W is not its key")
	send_key(KEY_W, false)
	check(ControlBindings.get_key(&"action_w") == KEY_Q and InputMap.action_get_events(&"action_w").size() == 1,
			"the InputMap has Q, and only Q, for action_w")
	check(signal_count[0] == 1 and counter.refreshes == 1, "bindings_changed is emitted and every key hint refreshes, once",
			"%d, %d" % [signal_count[0], counter.refreshes])
	send_key(KEY_W, true)
	check(not Input.is_action_pressed(&"action_w"), "W no longer triggers action_w")
	send_key(KEY_W, false)
	send_key(KEY_Q, true)
	check(Input.is_action_pressed(&"action_w"), "Q triggers action_w")
	send_key(KEY_Q, false)
	for action in ControlBindings.ACTIONS:
		if action != &"action_w":
			check(ControlBindings.get_key(action) == ControlBindings.DEFAULT_KEYS[action], "%s is unchanged" % action)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(manager.settings_path))
	check(data is Dictionary and data.keys().size() == 2 and data.get("settings_version") == 2.0 and data.get("keyboard") is Dictionary,
			"the settings file is written: settings_version 2 and the keyboard block, nothing else", str(data))
	var expected_keyboard := {}
	for action in ControlBindings.ACTIONS:
		expected_keyboard[String(action)] = DEFAULT_LABELS[action]
	expected_keyboard["action_w"] = "Q"
	check(data is Dictionary and data.get("keyboard") == expected_keyboard, "it stores each control by its action id and each key by its name", str(data))
	var text := FileAccess.get_file_as_string(manager.settings_path)
	check(manager.set_binding(&"action_w", KEY_Q) == "" and signal_count[0] == 1 and FileAccess.get_file_as_string(manager.settings_path) == text,
			"binding Q to Action Slot W again changes nothing and emits nothing")
	check(not FileAccess.file_exists(manager.settings_path + ".tmp"), "no temporary file is left behind")
	for pair: Array in [[&"move_up", KEY_I], [&"move_left", KEY_J], [&"move_down", KEY_K], [&"move_right", KEY_L],
			[&"action_a", KEY_2], [&"action_s", KEY_3], [&"action_d", KEY_4], [&"inventory_toggle", KEY_TAB], [&"action_w", KEY_1],
			[&"interact", KEY_F]]:
		check(manager.set_binding(pair[0], pair[1]) == "" and ControlBindings.get_key(pair[0]) == pair[1],
				"%s can be bound to %s" % [ControlBindings.get_display_name(pair[0]), ControlBindings.get_key_name(pair[1])])
	# The old keys are free again and the arrows can go anywhere.
	check(manager.set_binding(&"action_a", KEY_UP) == "" and ControlBindings.get_key_label(&"action_a") == "Up", "a free arrow key can go on an action slot")
	check(manager.set_binding(&"action_a", KEY_2) == "", "and back")
	for key: Key in [KEY_SPACE, KEY_COMMA, KEY_BRACKETLEFT, KEY_KP_1, KEY_BACKSPACE, KEY_PAGEDOWN, KEY_0, KEY_Z]:
		check(ControlBindings.get_key_problem(key) == "", "%s can be used for a control" % ControlBindings.get_key_name(key))
	manager.bindings_changed.disconnect(on_changed)
	counter.free()


func _check_refused_bindings() -> void:
	print("-- Refused bindings")
	var manager := _manager()
	var before: Dictionary = manager.get_bindings()
	var text := FileAccess.get_file_as_string(manager.settings_path)
	var cases: Array = [
		[&"inventory_toggle", KEY_1, "1 is already assigned to Action Slot W."],
		[&"action_w", KEY_I, "I is already assigned to Move Up."],
		[&"move_up", KEY_TAB, "Tab is already assigned to Inventory."],
		[&"move_right", KEY_J, "J is already assigned to Move Left."],
		[&"action_d", KEY_3, "3 is already assigned to Action Slot S."],
		[&"interact", KEY_1, "1 is already assigned to Action Slot W."],
		[&"action_a", KEY_F, "F is already assigned to Interact."],
		[&"interact", KEY_TAB, "Tab is already assigned to Inventory."],
		[&"interact", KEY_ESCAPE, "Escape is reserved for pausing and going back."],
		[&"action_w", KEY_ESCAPE, "Escape is reserved for pausing and going back."],
		[&"move_up", KEY_ENTER, "Enter is reserved for confirming in menus."],
		[&"inventory_toggle", KEY_KP_ENTER, "Enter is reserved for confirming in menus."],
		[&"action_w", KEY_SHIFT, "Shift cannot be used for a control."],
		[&"action_w", KEY_CTRL, "Ctrl cannot be used for a control."],
		[&"action_w", KEY_ALT, "Alt cannot be used for a control."],
		[&"action_w", KEY_META, ""],
		[&"action_w", KEY_CAPSLOCK, ""],
		[&"action_w", KEY_F1, ""],
		[&"action_w", KEY_F10, ""],
		[&"action_w", KEY_VOLUMEUP, ""],
		[&"action_w", KEY_NONE, "That key cannot be used for a control."],
	]
	for case: Array in cases:
		var message: String = manager.set_binding(case[0], case[1])
		var expected: String = case[2] if not (case[2] as String).is_empty() else "%s cannot be used for a control." % ControlBindings.get_key_name(case[1])
		check(message == expected and manager.get_bindings() == before and FileAccess.get_file_as_string(manager.settings_path) == text,
				"%s -> %s is refused: \"%s\"; nothing changes" % [ControlBindings.get_display_name(case[0]), ControlBindings.get_key_name(case[1]), expected], message)
	for action in ControlBindings.ACTIONS:
		check(ControlBindings.get_key(action) == before[action], "after the refusals %s still has %s" % [action, ControlBindings.get_key_name(before[action])])


func _check_loading() -> void:
	print("-- Loading")
	var manager := _manager()
	manager.reset_to_defaults()
	_write_settings({"settings_version": 2, "keyboard": CUSTOM_KEYBOARD})
	check(manager.load_settings() and not manager.load_failed and manager.migrated_from_version == 0, "a valid version 2 file loads, as it is")
	for action in ControlBindings.ACTIONS:
		check(ControlBindings.get_key_label(action) == CUSTOM_KEYBOARD[String(action)], "%s is %s from the file" % [action, CUSTOM_KEYBOARD[String(action)]])
	manager.delete_settings_file()
	check(manager.load_settings() and manager.is_default() and not manager.load_failed, "no file: the defaults, nothing went wrong")
	# A finished temporary file left by an interrupted write is used.
	var temp := FileAccess.open(manager.settings_path + ".tmp", FileAccess.WRITE)
	temp.store_string(JSON.stringify({"settings_version": 2, "keyboard": CUSTOM_KEYBOARD}))
	temp.close()
	check(manager.has_settings_file() and manager.load_settings() and ControlBindings.get_key(&"move_up") == KEY_I,
			"a finished temporary file left by an interrupted write is loaded")
	check(manager.set_binding(&"move_up", KEY_O) == "" and FileAccess.file_exists(manager.settings_path)
			and not FileAccess.file_exists(manager.settings_path + ".tmp"), "the next change writes the real file and leaves no temporary one")


func _check_bad_files() -> void:
	print("-- Bad settings files")
	var manager := _manager()
	var valid_text := JSON.stringify({"settings_version": 2, "keyboard": CUSTOM_KEYBOARD})
	var v1_duplicate := V1_KEYBOARD.duplicate()
	v1_duplicate["action_w"] = "I"
	var v1_with_interact := V1_KEYBOARD.duplicate()
	v1_with_interact["interact"] = "E"
	var bad_files: Dictionary = {
		"truncated JSON": valid_text.substr(0, valid_text.length() / 2),
		"an empty file": "",
		"not JSON": "controls = arrows",
		"a list": "[]",
		"a number": "1",
		"settings_version 3 (a newer game's)": _json_with("settings_version", 3),
		"settings_version 999": _json_with("settings_version", 999),
		"settings_version 0": _json_with("settings_version", 0),
		"settings_version \"2\"": _json_with("settings_version", "2"),
		"settings_version 1.5": _json_with("settings_version", 1.5),
		"no settings_version": _json_without("settings_version"),
		"no keyboard block": _json_without("keyboard"),
		"a keyboard list": _json_with("keyboard", ["I", "K"]),
		"an extra field": _json_with("save_version", 3),
		"a missing control": _keyboard_json("inventory_toggle", null),
		"a version 2 file without Interact": _keyboard_json("interact", null),
		"a version 1 file naming Interact": JSON.stringify({"settings_version": 1, "keyboard": v1_with_interact}),
		"a version 1 file with a duplicate key": JSON.stringify({"settings_version": 1, "keyboard": v1_duplicate}),
		"Interact on a slot's key": _keyboard_json("interact", "1"),
		"Interact on Escape": _keyboard_json("interact", "Escape"),
		"an unknown control": _keyboard_json("jump", "Z"),
		"a duplicate key (movement and slot)": _keyboard_json("action_w", "I"),
		"a duplicate key (two slots)": _keyboard_json("action_a", "1"),
		"Escape": _keyboard_json("action_w", "Escape"),
		"Enter": _keyboard_json("inventory_toggle", "Enter"),
		"Kp Enter": _keyboard_json("inventory_toggle", "Kp Enter"),
		"Shift alone": _keyboard_json("action_d", "Shift"),
		"F1": _keyboard_json("action_d", "F1"),
		"an unknown key name": _keyboard_json("move_up", "NotAKey"),
		"an empty key name": _keyboard_json("move_up", ""),
		"a lower-case key name": _keyboard_json("move_up", "i"),
		"a key code number": _keyboard_json("move_up", 73),
		"null for a key": _keyboard_json("move_up", "<null>"),
	}
	check(bad_files.size() == 33, "33 kinds of bad file", str(bad_files.size()))
	for label: String in bad_files:
		manager.set_binding(&"action_d", KEY_4)
		manager.set_binding(&"move_up", KEY_O)
		var file := FileAccess.open(manager.settings_path, FileAccess.WRITE)
		file.store_string(bad_files[label])
		file.close()
		var loaded: bool = manager.load_settings()
		check(not loaded and manager.load_failed and manager.is_default() and not (manager.last_error as String).is_empty()
				and manager.migrated_from_version == 0, "%s: not loaded, the defaults apply" % label, manager.last_error)
		check(ControlBindings.get_key(&"move_up") == KEY_UP and ControlBindings.get_key(&"action_d") == KEY_D
				and ControlBindings.get_key(&"inventory_toggle") == KEY_SPACE, "%s: the InputMap has the defaults" % label)
		check(FileAccess.get_file_as_string(manager.settings_path) == bad_files[label], "%s: the file is left as it was" % label)
	check(manager.set_binding(&"action_w", KEY_Q) == "" and not manager.load_failed, "the next change clears the failure")
	check(manager.load_settings() and ControlBindings.get_key(&"action_w") == KEY_Q, "and replaces the bad file with a valid one")
	manager.delete_settings_file()
	manager.load_settings()


func _check_safe_write() -> void:
	print("-- Safe write")
	var manager := _manager()
	manager.set_binding(&"action_w", KEY_Q)
	var text := FileAccess.get_file_as_string(manager.settings_path)
	# A folder where the temporary file would go makes the write fail part-way.
	DirAccess.make_dir_absolute(manager.settings_path + ".tmp")
	var message: String = manager.set_binding(&"action_w", KEY_R)
	var errors := take_engine_messages()
	check(message == "" and manager.last_save_failed and ControlBindings.get_key(&"action_w") == KEY_R,
			"a failed write still applies the binding for this session, and says it was not saved")
	check(errors.size() == 1 and errors[0].contains("Could not write the settings file"), "the failure is reported", str(errors))
	check(FileAccess.get_file_as_string(manager.settings_path) == text, "the old settings file is exactly as it was")
	DirAccess.remove_absolute(manager.settings_path + ".tmp")
	check(manager.set_binding(&"action_w", KEY_Q) == "" and not manager.last_save_failed, "writing works again once the way is clear")


func _check_reset() -> void:
	print("-- Reset to Defaults")
	var manager := _manager()
	for action in ControlBindings.ACTIONS:
		manager.set_binding(action, ControlBindings.get_key_from_name(CUSTOM_KEYBOARD[String(action)]))
	check(not manager.is_default(), "custom bindings before the reset")
	check(manager.reset_to_defaults() and manager.is_default(), "Reset to Defaults restores the ten defaults")
	for action in ControlBindings.ACTIONS:
		check(ControlBindings.get_key_label(action) == DEFAULT_LABELS[action], "%s is %s again in the InputMap" % [action, DEFAULT_LABELS[action]])
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(manager.settings_path))
	check(data is Dictionary and data.get("keyboard", {}).get("inventory_toggle") == "Space" and data.get("keyboard", {}).get("action_w") == "W"
			and data.get("keyboard", {}).get("interact") == "E" and data.get("settings_version") == 2.0,
			"and writes them to the settings file (Interact E, version 2)", str(data))
	check(manager.load_settings() and manager.is_default(), "which loads back as the defaults")


func _check_independence_from_the_save() -> void:
	print("-- Settings and the save are independent")
	var manager := _manager()
	var state := game_state()
	state.start_new_run()
	state.inventory.add(POTION, 1)
	state.inventory.add(SLINGSHOT, 1)
	state.action_slots.assign(SLINGSHOT, ActionSlots.SLOT_W)
	state.action_slots.assign(POTION, ActionSlots.SLOT_A)
	state.record_floor_entry(FLOOR_6_PATH)
	check(save_manager().save_checkpoint(state.floor_entry), "a Floor 6 checkpoint is saved")
	var save_text := FileAccess.get_file_as_string(save_manager().save_path)
	var save_time := FileAccess.get_modified_time(save_manager().save_path)
	var layout: Dictionary = state.action_slots.get_layout()
	check(manager.set_binding(&"action_w", KEY_Q) == "" and manager.set_binding(&"action_a", KEY_R) == "", "Action Slots W and A move to Q and R")
	check(state.action_slots.get_layout() == layout and state.action_slots.get_action(ActionSlots.SLOT_W) == SLINGSHOT
			and state.action_slots.get_action(ActionSlots.SLOT_A) == POTION and state.inventory.get_quantity(POTION) == 1,
			"the slots still hold the Slingshot on W and the potion on A: a key change moves nothing")
	manager.reset_to_defaults()
	manager.load_settings()
	check(FileAccess.get_file_as_string(save_manager().save_path) == save_text and FileAccess.get_modified_time(save_manager().save_path) == save_time,
			"changing, resetting and loading settings never rewrite the save")
	var saved: Variant = JSON.parse_string(save_text)
	check(save_manager().SAVE_VERSION == 3 and saved is Dictionary and saved.get("save_version") == 3.0 and saved.size() == 7
			and not saved.has("keyboard") and not saved.has("settings_version") and not saved.has("controls"),
			"the save is still version 3 with its seven fields, and holds no bindings", str(saved.keys()) if saved is Dictionary else "")
	manager.set_binding(&"action_w", KEY_Q)
	var settings: Variant = JSON.parse_string(FileAccess.get_file_as_string(manager.settings_path))
	check(settings is Dictionary and settings.size() == 2 and settings.has("settings_version") and settings.has("keyboard"),
			"the settings file holds no run state", str(settings))
	var settings_text := FileAccess.get_file_as_string(manager.settings_path)
	state.start_new_run()
	check(ControlBindings.get_key(&"action_w") == KEY_Q, "a new run keeps Action Slot W on Q")
	state.end_run()
	check(ControlBindings.get_key(&"action_w") == KEY_Q, "the end of a run (the title screen) keeps it too")
	save_manager().delete_save()
	check(not save_manager().has_save_file() and ControlBindings.get_key(&"action_w") == KEY_Q
			and FileAccess.get_file_as_string(manager.settings_path) == settings_text,
			"deleting the save changes neither the bindings nor the settings file")
	state.start_new_run()


## The custom settings with `field` set to `value`.
func _json_with(field: String, value: Variant) -> String:
	var data := {"settings_version": 2, "keyboard": CUSTOM_KEYBOARD.duplicate()}
	data[field] = value
	return JSON.stringify(data)


func _json_without(field: String) -> String:
	var data := {"settings_version": 2, "keyboard": CUSTOM_KEYBOARD.duplicate()}
	data.erase(field)
	return JSON.stringify(data)


## The custom settings with `action` bound to `key_name` (null: left out; "<null>": JSON null).
func _keyboard_json(action: String, key_name: Variant) -> String:
	var keyboard := CUSTOM_KEYBOARD.duplicate()
	if key_name == null:
		keyboard.erase(action)
	elif key_name is String and key_name == "<null>":
		keyboard[action] = null
	else:
		keyboard[action] = key_name
	return JSON.stringify({"settings_version": 2, "keyboard": keyboard})


func _check_migration() -> void:
	print("-- Version 1 settings are migrated (Phase 14)")
	var manager := _manager()
	check(manager.INTERACT_MIGRATION_KEYS == [KEY_E, KEY_F, KEY_R, KEY_T, KEY_G, KEY_Y, KEY_H, KEY_U, KEY_V, KEY_B, KEY_N, KEY_M,
			KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0], "the fallback order for Interact: E, F, R, T, G, Y, H, U, V, B, N, M, 5, 6, 7, 8, 9, 0")
	check(manager.VERSION_1_ACTIONS == ControlBindings.ACTIONS.slice(0, 9), "a version 1 file binds the first nine controls")
	# A save beside the settings, which migration must never touch.
	var state := game_state()
	state.start_new_run()
	state.record_floor_entry("res://scenes/levels/floor_07.tscn")
	save_manager().save_checkpoint(state.floor_entry)
	var save_text := FileAccess.get_file_as_string(save_manager().save_path)
	# The two real Phase 13 files.
	var cases: Array = [
		[V1_CUSTOM_FIXTURE, "E", "the real Phase 13 file with I/J/K/L, 1/2/3/4 and Tab (E free)"],
		[V1_E_TAKEN_FIXTURE, "R", "the real Phase 13 file with E and F on the W and A slots"],
	]
	for case: Array in cases:
		var fixture_text := FileAccess.get_file_as_string(case[0])
		var fixture: Dictionary = JSON.parse_string(fixture_text)
		check(fixture.get("settings_version") == 1.0 and fixture.get("keyboard", {}).size() == 9, "%s: is version 1 with nine keys" % case[2])
		_write_text(fixture_text)
		check(manager.load_settings() and not manager.load_failed and manager.migrated_from_version == 1, "%s: loads, migrated from version 1" % case[2],
				manager.last_error)
		for action: String in fixture["keyboard"]:
			check(ControlBindings.get_key_label(StringName(action)) == fixture["keyboard"][action],
					"%s: %s keeps %s" % [case[2], action, fixture["keyboard"][action]])
		check(ControlBindings.get_key_label(&"interact") == case[1], "%s: Interact gets %s" % [case[2], case[1]], ControlBindings.get_key_label(&"interact"))
		check(_all_different(), "%s: all ten keys are different" % case[2])
		var written: Variant = JSON.parse_string(FileAccess.get_file_as_string(manager.settings_path))
		var expected_keyboard: Dictionary = fixture["keyboard"].duplicate()
		expected_keyboard["interact"] = case[1]
		check(written is Dictionary and written.size() == 2 and written.get("settings_version") == 2.0 and written.get("keyboard") == expected_keyboard,
				"%s: the file is rewritten as version 2 with the ten keys" % case[2], str(written))
		check(not FileAccess.file_exists(manager.settings_path + ".tmp") and not manager.last_save_failed, "%s: safely (no temporary file left)" % case[2])
		var migrated_text := FileAccess.get_file_as_string(manager.settings_path)
		check(manager.load_settings() and manager.migrated_from_version == 0 and ControlBindings.get_key_label(&"interact") == case[1]
				and FileAccess.get_file_as_string(manager.settings_path) == migrated_text,
				"%s: the next load reads version 2 as it is (no second migration, nothing rewritten)" % case[2])
	# E already used by movement; the first nine fallback keys all used.
	var e_on_move := V1_KEYBOARD.duplicate()
	e_on_move["move_up"] = "E"
	var nine_taken := {"move_up": "E", "move_down": "F", "move_left": "R", "move_right": "T",
			"action_w": "G", "action_a": "Y", "action_s": "H", "action_d": "U", "inventory_toggle": "V"}
	for pair: Array in [[e_on_move, "F", "E on Move Up"], [nine_taken, "B", "E, F, R, T, G, Y, H, U, V all taken"]]:
		for attempt in 2:
			_write_settings({"settings_version": 1, "keyboard": pair[0]})
			check(manager.load_settings() and manager.migrated_from_version == 1 and ControlBindings.get_key_label(&"interact") == pair[1]
					and _all_different(), "%s: Interact gets %s, nothing else moves (attempt %d)" % [pair[2], pair[1], attempt + 1])
			for action: String in pair[0]:
				check(ControlBindings.get_key_label(StringName(action)) == pair[0][action], "%s: %s keeps %s" % [pair[2], action, pair[0][action]])
	# Invalid version 1 files: the defaults, and the file untouched.
	var v1_escape := V1_KEYBOARD.duplicate()
	v1_escape["inventory_toggle"] = "Escape"
	var v1_missing := V1_KEYBOARD.duplicate()
	v1_missing.erase("action_d")
	var v1_twice := V1_KEYBOARD.duplicate()
	v1_twice["action_a"] = "1"
	for bad: Array in [[v1_escape, "Escape"], [v1_missing, "a missing control"], [v1_twice, "a key used twice"]]:
		var text := JSON.stringify({"settings_version": 1, "keyboard": bad[0]})
		_write_text(text)
		check(not manager.load_settings() and manager.load_failed and manager.is_default() and manager.migrated_from_version == 0
				and FileAccess.get_file_as_string(manager.settings_path) == text,
				"a version 1 file with %s: the defaults, and the file is not rewritten" % bad[1], manager.last_error)
	# The write-back fails: the migrated keys still apply, the version 1 file stays as it was.
	var v1_text := JSON.stringify({"settings_version": 1, "keyboard": V1_KEYBOARD})
	_write_text(v1_text)
	DirAccess.make_dir_absolute(manager.settings_path + ".tmp")
	var loaded: bool = manager.load_settings()
	var errors := take_engine_messages()
	check(loaded and manager.migrated_from_version == 1 and manager.last_save_failed and ControlBindings.get_key(&"move_up") == KEY_I
			and ControlBindings.get_key(&"interact") == KEY_E, "a failed write-back: the migrated keys apply for this session")
	check(errors.size() == 1 and errors[0].contains("Could not write the settings file") and FileAccess.get_file_as_string(manager.settings_path) == v1_text,
			"it is reported, and the version 1 file is exactly as it was", str(errors))
	DirAccess.remove_absolute(manager.settings_path + ".tmp")
	check(manager.load_settings() and manager.migrated_from_version == 1 and JSON.parse_string(FileAccess.get_file_as_string(manager.settings_path)).get("settings_version") == 2.0,
			"the next load migrates it again, this time written as version 2")
	# A leftover version 1 temporary file (no settings file) is migrated and becomes the settings file.
	manager.delete_settings_file()
	var temp := FileAccess.open(manager.settings_path + ".tmp", FileAccess.WRITE)
	temp.store_string(v1_text)
	temp.close()
	check(manager.load_settings() and manager.migrated_from_version == 1 and ControlBindings.get_key(&"interact") == KEY_E
			and FileAccess.file_exists(manager.settings_path) and not FileAccess.file_exists(manager.settings_path + ".tmp")
			and JSON.parse_string(FileAccess.get_file_as_string(manager.settings_path)).get("settings_version") == 2.0,
			"a leftover version 1 temporary file is migrated and written as the version 2 settings file")
	# No fallback key free: impossible from a real version 1 file (nine keys, eighteen candidates),
	# but the migration still gives up cleanly rather than bind anything.
	var all_taken: Dictionary[StringName, Key] = {}
	for key: Key in manager.INTERACT_MIGRATION_KEYS:
		all_taken[StringName("taken_%d" % key)] = key
	check(manager._migrate_version_1(all_taken).is_empty() and (manager.last_error as String).contains("no key free for Interact"),
			"with every fallback key taken, the migration gives up (nothing applied)", manager.last_error)
	check(FileAccess.get_file_as_string(save_manager().save_path) == save_text, "migrating settings never touched the save")
	save_manager().delete_save()
	manager.delete_settings_file()
	manager.reset_to_defaults()
	manager.delete_settings_file()
	manager.load_settings()


## True if every control has a different key.
func _all_different() -> bool:
	var keys := {}
	for action in ControlBindings.ACTIONS:
		keys[ControlBindings.get_key(action)] = true
	return keys.size() == ControlBindings.ACTIONS.size() and not keys.has(KEY_NONE)


func _write_text(text: String) -> void:
	var file := FileAccess.open(_manager().settings_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _write_settings(data: Dictionary) -> void:
	var file := FileAccess.open(_manager().settings_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
