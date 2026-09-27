extends "res://tests/support/game_test.gd"
## Phase 13: control settings across application restarts, each run in a separate Godot process
## (tests/support/settings_child.gd) that loads this test's own settings file at startup exactly as
## the game loads user://settings.json, and Continues from this test's own Floor 7 save (Slingshot on
## the W slot, potions on A, Blast Bombs on S, Bat on D).
## - Custom bindings (I/K/J/L, 1/2/3/4, Tab) written by one process are in the InputMap of a fresh
##   one before any scene exists; its title shows no settings message, its Settings screen lists
##   them, Continue opens Floor 7 with the same four slot contents, the HUD names 1/2/3/4 and Tab, I
##   moves Carl and Up does not, 1 fires the Slingshot and W does not, Tab opens the action menu and
##   Space does not. Neither the settings file nor the save changes (Continue re-saves the same
##   checkpoint).
## - A process that confirms Reset to Defaults on the title and quits through Quit Game (exit code
##   0) leaves the defaults in the settings file; the next fresh process starts with them (arrows,
##   W, Space), the save still the same.
## - Bad settings files (truncated JSON, an unsupported version, a duplicate key, Escape stored as a
##   key, a missing control): the fresh process starts with the defaults, the title says "Control
##   settings could not be loaded. Defaults restored.", Continue still loads the valid save and the
##   default keys play; the bad file and the save are left as they were.
## - A process told to load the player's own settings file (user://settings.json) refuses it with an
##   error at startup and uses the defaults; that file is neither created nor changed.
## - Phase 14 (settings version 2, Interact): the fresh process's Settings screen lists Interact (E);
##   at Floor 7's chest the prompt names the Interact key, another key does nothing and the Interact
##   key opens it. The two real Phase 13 settings files (version 1, written by the Phase 13 game)
##   start a fresh process with their nine keys and Interact on E (I/J/K/L, 1/2/3/4, Tab) or, with
##   E and F taken, on R; the Settings screen and the chest prompt show that key and it opens the
##   chest while E does not; the file is then version 2 with the ten keys, and the next fresh process
##   reads it as it is (no second migration, the file unchanged). An unsupported version 3 file and a
##   version 2 file without Interact are bad files like the others.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_settings_restart.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const CHILD_SCRIPT := "res://tests/support/settings_child.gd"
const FLOOR_7_PATH := "res://scenes/levels/floor_07.tscn"
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const SLINGSHOT: ActionDefinition = preload("res://resources/actions/slingshot.tres")
const BAT: ActionDefinition = preload("res://resources/actions/baseball_bat.tres")
const BOMB: ActionDefinition = preload("res://resources/actions/blast_bomb.tres")
const CUSTOM_KEYS := "move_up=I move_down=K move_left=J move_right=L action_w=1 action_a=2 action_s=3 action_d=4 inventory_toggle=Tab interact=E"
const DEFAULT_KEYS := "move_up=Up move_down=Down move_left=Left move_right=Right action_w=W action_a=A action_s=S action_d=D inventory_toggle=Space interact=E"
const V1_CUSTOM_FIXTURE := "res://tests/fixtures/phase13_settings_v1_custom.json"
const V1_E_TAKEN_FIXTURE := "res://tests/fixtures/phase13_settings_v1_e_taken.json"
const SLOTS_LINE := "CHILD: slots action_w=slingshot action_a=small_health_potion action_s=blast_bomb action_d=baseball_bat"

var _save_text := ""


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	_seed_files()
	_check_custom_bindings_in_a_fresh_process()
	_check_reset_then_fresh_process()
	_check_bad_settings_files()
	_check_player_settings_refused()
	_check_version_1_files_migrate()
	finish()


func _seed_files() -> void:
	var state := game_state()
	state.start_new_run()
	state.inventory.add(POTION, 2)
	state.inventory.add(BOMB, 2)
	state.inventory.add(SLINGSHOT, 1)
	state.inventory.add(BAT, 1)
	state.action_slots.assign(SLINGSHOT, ActionSlots.SLOT_W)
	state.action_slots.assign(POTION, ActionSlots.SLOT_A)
	state.action_slots.assign(BOMB, ActionSlots.SLOT_S)
	state.action_slots.assign(BAT, ActionSlots.SLOT_D)
	state.carl_health = 70
	state.record_floor_entry(FLOOR_7_PATH)
	check(save_manager().save_checkpoint(state.floor_entry), "a Floor 7 checkpoint is saved")
	state.start_new_run()
	_save_text = FileAccess.get_file_as_string(save_manager().save_path)
	# The custom bindings, written the way the game writes them.
	for pair: Array in [[&"move_up", KEY_I], [&"move_down", KEY_K], [&"move_left", KEY_J], [&"move_right", KEY_L],
			[&"action_w", KEY_1], [&"action_a", KEY_2], [&"action_s", KEY_3], [&"action_d", KEY_4], [&"inventory_toggle", KEY_TAB]]:
		settings_manager().set_binding(pair[0], pair[1])
	check(FileAccess.file_exists(settings_manager().settings_path), "the custom bindings are written to this test's settings file")


func _check_custom_bindings_in_a_fresh_process() -> void:
	print("-- Custom bindings in a fresh process")
	var settings_text := FileAccess.get_file_as_string(settings_manager().settings_path)
	var lines := _run_child("play")
	check("CHILD: startup scene=none keys=%s load_failed=false" % CUSTOM_KEYS in lines,
			"the fresh process has the custom keys in the InputMap before any scene exists")
	check("CHILD: title continue=true settings_message=<none>" in lines, "its title offers Continue and no settings message")
	check("CHILD: settings screen open=true keys=I|K|J|L|1|2|3|4|Tab|E" in lines, "its Settings screen lists the custom keys, and Interact E")
	check("CHILD: startup migrated_from_version=0" in lines, "a version 2 file needs no migration")
	check("CHILD: entered floor_07.tscn hud=1: Slingshot   2: Potion x2   3: Blast Bomb x2   4: Baseball Bat | Tab: action menu     Esc: pause" in lines,
			"Continue opens Floor 7; the HUD names 1/2/3/4 and Tab")
	check(SLOTS_LINE in lines, "the four slots hold what the save says")
	check("CHILD: held I moved (0.0, -63.0)" in lines and "CHILD: held Up moved (0.0, 0.0)" in lines, "I moves Carl, Up does not")
	check("CHILD: pressed W stones=0" in lines and "CHILD: pressed 1 stones=1" in lines, "1 fires the Slingshot, W does not")
	check("CHILD: pressed Space action_menu_open=false" in lines and "CHILD: pressed Tab action_menu_open=true" in lines,
			"Tab opens the action menu, Space does not")
	check("CHILD: chest prompt=E: Open Chest" in lines and "CHILD: pressed Q chest_open=false" in lines and "CHILD: pressed E chest_open=true" in lines,
			"at Floor 7's chest: \"E: Open Chest\", Q does nothing, E opens it")
	check(FileAccess.get_file_as_string(settings_manager().settings_path) == settings_text, "the settings file is unchanged")
	check(FileAccess.get_file_as_string(save_manager().save_path) == _save_text, "the save is still the same checkpoint")


func _check_reset_then_fresh_process() -> void:
	print("-- Reset to Defaults, quit, fresh process")
	var lines := _run_child("reset")
	check("CHILD: startup scene=none keys=%s load_failed=false" % CUSTOM_KEYS in lines, "the process starts with the custom keys")
	check("CHILD: after Reset to Defaults keys=%s message=All controls are back to their defaults." % DEFAULT_KEYS in lines,
			"Settings > Reset to Defaults > Yes gives the defaults")
	check("CHILD: quitting from the title, Quit Game selected=true" in lines and "CHILD: done" not in lines,
			"the game itself ended the process through Quit Game")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(settings_manager().settings_path))
	var keyboard: Dictionary = data.get("keyboard", {}) if data is Dictionary else {}
	check(data is Dictionary and data.get("settings_version") == 2.0 and keyboard.get("move_up") == "Up" and keyboard.get("action_w") == "W"
			and keyboard.get("inventory_toggle") == "Space" and keyboard.get("interact") == "E" and keyboard.size() == 10,
			"the settings file now holds the ten defaults", str(data))
	lines = _run_child("play")
	check("CHILD: startup scene=none keys=%s load_failed=false" % DEFAULT_KEYS in lines, "the next fresh process starts with the defaults")
	check("CHILD: entered floor_07.tscn hud=W: Slingshot   A: Potion x2   S: Blast Bomb x2   D: Baseball Bat | Space: action menu     Esc: pause" in lines
			and SLOTS_LINE in lines, "Continue: the same slots, now under W/A/S/D")
	check("CHILD: held I moved (0.0, 0.0)" in lines and "CHILD: held Up moved (0.0, -63.0)" in lines, "Up moves Carl again, I does not")
	check("CHILD: pressed W stones=1" in lines and "CHILD: pressed Space action_menu_open=true" in lines, "W fires and Space opens the menu")
	check(FileAccess.get_file_as_string(save_manager().save_path) == _save_text, "the save is still the same checkpoint")


func _check_bad_settings_files() -> void:
	print("-- Bad settings files at startup")
	var custom := {"move_up": "I", "move_down": "K", "move_left": "J", "move_right": "L",
			"action_w": "1", "action_a": "2", "action_s": "3", "action_d": "4", "inventory_toggle": "Tab"}
	var custom_v2 := custom.duplicate()
	custom_v2["interact"] = "E"
	var valid := JSON.stringify({"settings_version": 1, "keyboard": custom})
	var duplicate := custom.duplicate()
	duplicate["action_w"] = "I"
	var escape := custom.duplicate()
	escape["inventory_toggle"] = "Escape"
	var missing := custom.duplicate()
	missing.erase("action_d")
	var bad_files := {
		"truncated JSON": valid.substr(0, 40),
		"settings_version 3": JSON.stringify({"settings_version": 3, "keyboard": custom_v2}),
		"a version 2 file without Interact": JSON.stringify({"settings_version": 2, "keyboard": custom}),
		"a duplicate key": JSON.stringify({"settings_version": 1, "keyboard": duplicate}),
		"Escape as a key": JSON.stringify({"settings_version": 1, "keyboard": escape}),
		"a missing control": JSON.stringify({"settings_version": 1, "keyboard": missing}),
	}
	for label: String in bad_files:
		var file := FileAccess.open(settings_manager().settings_path, FileAccess.WRITE)
		file.store_string(bad_files[label])
		file.close()
		var lines := _run_child("play")
		check("CHILD: startup scene=none keys=%s load_failed=true" % DEFAULT_KEYS in lines, "%s: the game starts with the defaults" % label)
		check("CHILD: title continue=true settings_message=Control settings could not be loaded. Defaults restored." in lines,
				"%s: the title says so, and Continue is still offered" % label)
		check("CHILD: entered floor_07.tscn hud=W: Slingshot   A: Potion x2   S: Blast Bomb x2   D: Baseball Bat | Space: action menu     Esc: pause" in lines
				and SLOTS_LINE in lines, "%s: the valid save still continues, with its slots" % label)
		check("CHILD: held Up moved (0.0, -63.0)" in lines and "CHILD: pressed W stones=1" in lines, "%s: the default keys play" % label)
		check(FileAccess.get_file_as_string(settings_manager().settings_path) == bad_files[label], "%s: the bad file is left as it was" % label)
		check(FileAccess.get_file_as_string(save_manager().save_path) == _save_text, "%s: the save is untouched" % label)


func _check_player_settings_refused() -> void:
	print("-- The player's settings file is refused at startup")
	var player_file := "user://settings.json"
	var existed := FileAccess.file_exists(player_file)
	var modified_time := FileAccess.get_modified_time(player_file) if existed else 0
	var lines := _run_child("production", player_file)
	check(lines.any(func(line: String) -> bool: return line.contains("SettingsManager refused to use user://settings.json")),
			"SettingsManager refuses it with an error")
	check("CHILD: startup scene=none keys=%s load_failed=false" % DEFAULT_KEYS in lines and "CHILD: done" in lines,
			"the process starts with the defaults and carries on")
	check(FileAccess.file_exists(player_file) == existed and (not existed or FileAccess.get_modified_time(player_file) == modified_time),
			"the player's settings file is neither created nor changed")


func _check_version_1_files_migrate() -> void:
	print("-- Real Phase 13 (version 1) settings files, migrated in fresh processes")
	for case: Array in [[V1_CUSTOM_FIXTURE, "E", "Q", "E free"], [V1_E_TAKEN_FIXTURE, "R", "E", "E and F taken"]]:
		var fixture_text := FileAccess.get_file_as_string(case[0])
		var fixture: Dictionary = JSON.parse_string(fixture_text)
		var keyboard: Dictionary = fixture["keyboard"]
		var file := FileAccess.open(settings_manager().settings_path, FileAccess.WRITE)
		file.store_string(fixture_text)
		file.close()
		var expected_keys := " ".join(ControlBindings.ACTIONS.map(func(action: StringName) -> String:
			return "%s=%s" % [action, keyboard.get(String(action), case[1])]))
		var screen_keys := "|".join(ControlBindings.ACTIONS.map(func(action: StringName) -> String: return keyboard.get(String(action), case[1])))
		var lines := _run_child("play")
		check(fixture.get("settings_version") == 1.0 and "CHILD: startup scene=none keys=%s load_failed=false" % expected_keys in lines,
				"%s: the fresh process starts with the nine Phase 13 keys and Interact on %s" % [case[3], case[1]])
		check("CHILD: startup migrated_from_version=1" in lines, "%s: the file was migrated from version 1" % case[3])
		check("CHILD: title continue=true settings_message=<none>" in lines, "%s: no settings message; Continue is offered" % case[3])
		check("CHILD: settings screen open=true keys=%s" % screen_keys in lines, "%s: the Settings screen lists Interact as %s" % [case[3], case[1]])
		check("CHILD: held I moved (0.0, -63.0)" in lines and "CHILD: held Up moved (0.0, 0.0)" in lines, "%s: the migrated movement keys play" % case[3])
		check("CHILD: chest prompt=%s: Open Chest" % case[1] in lines and "CHILD: pressed %s chest_open=false" % case[2] in lines
				and "CHILD: pressed %s chest_open=true" % case[1] in lines,
				"%s: the chest prompt says %s; %s does nothing and %s opens it" % [case[3], case[1], case[2], case[1]])
		var written_text := FileAccess.get_file_as_string(settings_manager().settings_path)
		var written: Variant = JSON.parse_string(written_text)
		var expected_keyboard := keyboard.duplicate()
		expected_keyboard["interact"] = case[1]
		check(written is Dictionary and written.get("settings_version") == 2.0 and written.get("keyboard") == expected_keyboard,
				"%s: the file is now version 2 with the ten keys" % case[3], written_text)
		check(FileAccess.get_file_as_string(save_manager().save_path) == _save_text, "%s: the save is untouched" % case[3])
		lines = _run_child("play")
		check("CHILD: startup scene=none keys=%s load_failed=false" % expected_keys in lines and "CHILD: startup migrated_from_version=0" in lines,
				"%s: the next fresh process reads version 2 with the same keys, no second migration" % case[3])
		check(FileAccess.get_file_as_string(settings_manager().settings_path) == written_text, "%s: and does not rewrite it" % case[3])


## Runs settings_child.gd in its own headless Godot process. Returns its output lines. A clean run
## (exit code 0, no engine error or warning) is checked here, except for the error mode
## "production" expects.
func _run_child(mode: String, settings_path: String = "") -> Array:
	if settings_path.is_empty():
		settings_path = settings_manager().settings_path
	var arguments := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", CHILD_SCRIPT, "--",
			"--settings-file=" + settings_path, "--save=" + save_manager().save_path, "--mode=" + mode])
	var output := []
	var exit_code := OS.execute(OS.get_executable_path(), arguments, output, true)
	var lines := Array("\n".join(output).replace("\r", "").split("\n"))
	check(exit_code == 0, "%s: the process exits with code 0" % mode, "exit code %d" % exit_code)
	var problems := lines.filter(func(line: String) -> bool:
		return (line.begins_with("ERROR") or line.begins_with("WARNING") or line.begins_with("SCRIPT ERROR") or line.contains("CrashHandler")
				or line.begins_with("CHILD REFUSED") or line.begins_with("CHILD: watchdog")) and not (mode == "production" and line.contains("SettingsManager refused")))
	check(problems.is_empty(), "%s: no engine error, warning, refusal or crash" % mode, "\n".join(problems))
	if exit_code != 0 or not problems.is_empty():
		print("      child output:\n      " + "\n      ".join(lines).replace("ERROR", "E-R-R-O-R"))
	return lines
