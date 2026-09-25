extends "res://tests/support/game_test.gd"
## Helper for test_quit_game.gd and test_title_quit.gd, which start it as a separate Godot
## process. Never run it on its own: it plays a real session that ends by closing the game, and
## prints what it saw as "CHILD: ..." lines for the parent test to check.
##     godot --headless --path . -s res://tests/support/quit_game_child.gd -- --save=<file> --mode=<mode>
## - --save: the save file to Continue from. It must be inside the test save folder; anything
##   else (the player's save, or no --save at all) is refused before anything runs: it prints
##   "CHILD REFUSED" and exits with code 2. The file is never deleted (unlike a normal test's).
## - --mode=pause_quit: Continue, change the live floor (hurt Carl and Donut, drink the potion,
##   kill an enemy, fire a stone), then pause and Quit Game: cancel once with Escape, once with
##   No, then Yes. The game itself closes the process.
## - --mode=window_close: the same session, then the window is closed the way the operating
##   system closes it (the close request the root window receives), with no pause menu involved.
## - --mode=title_quit (Phase 11): on the title screen, Down until Quit Game is selected, then
##   Enter. The file need not exist: with no save the title offers New Game and Quit Game.
## - --mode=return_title_quit (Phase 11): the pause_quit session up to the pause menu, then
##   Return to Title > Yes, and Quit Game on the title screen as in title_quit.
## If the session has not ended after a minute (for example a script error stopped it), it
## prints "CHILD: watchdog, giving up" and exits with code 4.

var _mode := ""


## Replaces the normal test setup: this run uses the save file it is given and never deletes it.
func _use_test_save_file() -> void:
	var save_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--save="):
			save_path = argument.trim_prefix("--save=")
		elif argument.begins_with("--mode="):
			_mode = argument.trim_prefix("--mode=")
	if not save_path.simplify_path().begins_with(TEST_SAVE_FOLDER) or _mode not in ["pause_quit", "window_close", "title_quit", "return_title_quit"]:
		print("CHILD REFUSED: save '%s' is not inside %s, or mode '%s' is unknown" % [save_path, TEST_SAVE_FOLDER, _mode])
		quit(2)
		return
	save_manager().save_path = save_path
	# A session that goes wrong (a script error stops _play()) must never leave the parent test
	# waiting forever: give up after a minute, with an exit code the parent reports.
	create_timer(60.0).timeout.connect(func() -> void:
		print("CHILD: watchdog, giving up")
		quit(4))
	_play.call_deferred()


func _initialize() -> void:
	pass


## This helper is meant to be ended by the game (Quit Game, the window closing), never by
## finish(), so game_test.gd's "ended before finish()" failure does not apply: the parent test
## checks the exit code and output instead.
func _finalize() -> void:
	pass


func _play() -> void:
	var title_path: String = ProjectSettings.get_setting("application/run/main_scene")
	change_scene_to_file(title_path)
	await wait_for_scene(title_path)
	print("CHILD: title says " + current_scene.get_node("%SaveInfoLabel").text)
	if _mode == "title_quit":
		await _quit_from_title()
		return
	await tap_key(KEY_ENTER)
	await wait_physics_frames(10)
	var level := current_scene
	var carl: Node2D = level.get_node("Actors/Carl")
	var donut: Node2D = level.get_node("Actors/Donut")
	print("CHILD: entered %s carl=%d donut=%d potions=%d" % [level.scene_file_path.get_file(),
			carl.health.current_health, donut.health.current_health, _potions()])
	print("CHILD: save after entry mtime=%d" % FileAccess.get_modified_time(save_manager().save_path))

	carl.get_node("Hurtbox").take_hit(50)
	donut.get_node("Hurtbox").take_hit(30)
	await tap_key(KEY_A)
	(level.get_node("Actors/BackstopBlob") as Enemy).health.take_damage(30)
	await wait_seconds(1.0)
	await tap_key(KEY_W)
	var enemies := level.get_node("Actors").get_children().filter(func(node: Node) -> bool: return node is Enemy).size()
	print("CHILD: live carl=%d donut=%d potions=%d enemies=%d" % [carl.health.current_health,
			donut.health.current_health, _potions(), enemies])

	if _mode == "window_close":
		print("CHILD: closing the window")
		root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		root.close_requested.emit()
	elif _mode == "return_title_quit":
		# Pause > Return to Title > Yes.
		await tap_key(KEY_ESCAPE)
		await tap_key(KEY_DOWN)
		await tap_key(KEY_ENTER)
		await tap_key(KEY_DOWN)
		await tap_key(KEY_ENTER)
		if not await wait_for_scene(title_path):
			quit(3)
			return
		print("CHILD: back on the title, it says " + current_scene.get_node("%SaveInfoLabel").text)
		await _quit_from_title()
		return
	else:
		var pause: CanvasLayer = level.get_node("PauseMenu")
		await tap_key(KEY_ESCAPE)
		await tap_key(KEY_DOWN)
		await tap_key(KEY_DOWN)
		await tap_key(KEY_ENTER)
		print("CHILD: quit question=%s yes_selected=%s" % [
				(pause.get_node("%ConfirmQuestion") as Label).text.replace("\n", " | "), pause.is_yes_selected()])
		await tap_key(KEY_ESCAPE)
		print("CHILD: after Escape confirming=%s open=%s paused=%s" % [pause.is_confirming(), pause.is_open(), paused])
		await tap_key(KEY_ENTER)
		await tap_key(KEY_ENTER)
		print("CHILD: after No confirming=%s open=%s paused=%s" % [pause.is_confirming(), pause.is_open(), paused])
		await tap_key(KEY_ENTER)
		await tap_key(KEY_DOWN)
		print("CHILD: quitting")
		send_key(KEY_ENTER, true)
	# The game closes the process at the end of this frame. If it is still running a while later,
	# it did not quit.
	await wait_physics_frames(120)
	print("CHILD: still running")
	quit(3)


## Selects Quit Game on the title screen with Down, then presses Enter, which should end the process.
func _quit_from_title() -> void:
	var title := current_scene
	var quit_option: int = title.get_script().get_script_constant_map()["Option"]["QUIT"]
	for i in 3:
		if title.get_selected_option() == quit_option:
			break
		await tap_key(KEY_DOWN)
	var rows := ["%ContinueRow", "%NewGameRow", "%QuitRow"].map(func(row: String) -> String: return title.get_node(row).text.strip_edges())
	print("CHILD: title rows %s, Quit Game selected=%s" % [" | ".join(rows), title.get_selected_option() == quit_option])
	print("CHILD: quitting from the title: carl_health=%d potions=%d floor_entry=%s" % [
			game_state().carl_health, _potions(), game_state().floor_entry])
	send_key(KEY_ENTER, true)
	await wait_physics_frames(120)
	print("CHILD: still running")
	quit(3)


func _potions() -> int:
	return game_state().inventory.get_quantity(preload("res://resources/actions/small_health_potion.tres"))
