extends "res://tests/support/game_test.gd"
## Helper for test_settings_restart.gd, which starts it as a separate Godot process so that the
## control settings are loaded exactly as at a real start: by SettingsManager itself, before any
## scene exists. Never run it on its own. It prints what it saw as "CHILD: ..." lines for the parent
## test to check, and never deletes or writes the files it is given (except through the game's own
## Settings screen in mode "reset").
##     godot --headless --path . -s res://tests/support/settings_child.gd -- --settings-file=<file> --save=<file> --mode=<mode>
## - --settings-file: read by SettingsManager at startup (its test-run rule). It must be inside the
##   test save folder, except in mode "production", where the parent checks that SettingsManager
##   refuses the player's file.
## - --save: the save file to Continue from, inside the test save folder.
## - --mode=play: the startup bindings; the title (its settings message, Continue, the Settings
##   screen's keys); Continue; movement with I and Up, the W slot with 1 and W, the Inventory key
##   with Tab and Space; then quits.
## - --mode=reset: the startup bindings; Settings > Reset to Defaults > Yes on the title screen, then
##   Quit Game on the title (the game ends the process).
## - --mode=production: the startup bindings and what SettingsManager did with its file; then quits.
## Anything else, or files outside the test folder, is refused: "CHILD REFUSED", exit code 2.
## A session that has not ended after a minute prints "CHILD: watchdog, giving up" (exit code 4).

const MODES: Array[String] = ["play", "reset", "production"]

var _mode := ""


## Replaces the normal test setup: this run uses the files it is given and never deletes them.
func _use_test_save_file() -> void:
	var save_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--save="):
			save_path = argument.trim_prefix("--save=")
		elif argument.begins_with("--mode="):
			_mode = argument.trim_prefix("--mode=")
	var settings_path: String = settings_manager().settings_path
	var settings_ok := settings_path.simplify_path().begins_with(TEST_SAVE_FOLDER) or _mode == "production"
	if not save_path.simplify_path().begins_with(TEST_SAVE_FOLDER) or not settings_ok or _mode not in MODES:
		print("CHILD REFUSED: save '%s', settings '%s', mode '%s'" % [save_path, settings_path, _mode])
		quit(2)
		return
	save_manager().save_path = save_path
	# The bindings SettingsManager applied before this script could do anything, and before any
	# scene was loaded.
	print("CHILD: startup scene=%s keys=%s load_failed=%s" % ["none" if current_scene == null else current_scene.name, _keys(), settings_manager().load_failed])
	create_timer(60.0).timeout.connect(func() -> void:
		print("CHILD: watchdog, giving up")
		quit(4))
	_play.call_deferred()


func _initialize() -> void:
	pass


## This helper ends by quitting (itself, or through the game's Quit Game), never through finish(),
## which would delete the files it was given.
func _finalize() -> void:
	pass


func _play() -> void:
	if _mode == "production":
		print("CHILD: settings_path=%s" % settings_manager().settings_path)
		_quit()
		return
	var title_path: String = ProjectSettings.get_setting("application/run/main_scene")
	change_scene_to_file(title_path)
	await wait_for_scene(title_path)
	var title := current_scene
	var info: Label = title.get_node("%SettingsInfoLabel")
	print("CHILD: title continue=%s settings_message=%s" % [title.is_continue_available(), info.text if info.visible else "<none>"])
	await tap_key(KEY_DOWN)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	var settings: Control = title.get_node("%SettingsMenu")
	var keys: Array = settings.get_node("%Rows").get_children().filter(func(row: Node) -> bool: return row is HBoxContainer).map(
			func(row: HBoxContainer) -> String: return (row.get_child(1) as Label).text)
	print("CHILD: settings screen open=%s keys=%s" % [settings.is_open(), "|".join(keys)])
	if _mode == "reset":
		while settings.get_selected_row() != ControlBindings.ACTIONS.size():
			await tap_key(KEY_UP)
		await tap_key(KEY_ENTER)
		await tap_key(KEY_DOWN)
		await tap_key(KEY_ENTER)
		print("CHILD: after Reset to Defaults keys=%s message=%s" % [_keys(), settings.get_message()])
		await tap_key(KEY_ESCAPE)
		# Quit Game, the row below Settings. The game itself ends the process.
		await tap_key(KEY_DOWN)
		print("CHILD: quitting from the title, Quit Game selected=%s" % (title.get_node("%QuitRow").text == "> Quit Game"))
		await tap_key(KEY_ENTER)
		return
	await tap_key(KEY_ESCAPE)
	await tap_key(KEY_UP)
	await tap_key(KEY_UP)
	await tap_key(KEY_ENTER)
	await wait_physics_frames(10)
	var level := current_scene
	var carl: Node2D = level.get_node("Actors/Carl")
	print("CHILD: entered %s hud=%s | %s" % [level.scene_file_path.get_file(), level.get_node("HUD/%ActionSlotsLabel").text, level.get_node("HUD/%MenuHint").text])
	var slots: ActionSlots = game_state().action_slots
	print("CHILD: slots %s" % " ".join(ActionSlots.SLOTS.map(func(slot: StringName) -> String:
		var action := slots.get_action(slot)
		return "%s=%s" % [slot, action.id if action != null else "-"])))
	for key: Key in [KEY_I, KEY_UP]:
		var start := carl.global_position
		await hold_keys([key], 20)
		print("CHILD: held %s moved %s" % [OS.get_keycode_string(key), carl.global_position - start])
	var stones := [0]
	(carl.get_action_performer(load("res://resources/actions/slingshot.tres")) as ProjectileLauncher).fired.connect(
			func(_stone: Projectile) -> void: stones[0] += 1)
	for key: Key in [KEY_W, KEY_1]:
		await tap_key(key)
		await wait_physics_frames(40)
		print("CHILD: pressed %s stones=%d" % [OS.get_keycode_string(key), stones[0]])
	var menu: CanvasLayer = level.get_node("ActionMenu")
	for key: Key in [KEY_SPACE, KEY_TAB]:
		await tap_key(key)
		print("CHILD: pressed %s action_menu_open=%s" % [OS.get_keycode_string(key), menu.is_open()])
		if menu.is_open():
			await tap_key(KEY_ESCAPE)
	_quit()


func _quit() -> void:
	print("CHILD: done")
	quit(0)


func _keys() -> String:
	return " ".join(ControlBindings.ACTIONS.map(func(action: StringName) -> String:
		return "%s=%s" % [action, ControlBindings.get_key_label(action)]))
