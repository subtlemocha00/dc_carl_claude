extends "res://tests/support/game_test.gd"
## Phase 10 Quit Game and window close, with real process exits. This test writes a Floor 6
## entry checkpoint (Carl 80 / 100, Donut 40 / 60, one potion, the Slingshot and the Bat) to its
## own save file, then starts tests/support/quit_game_child.gd as a separate Godot process on that
## file, twice:
## - pause_quit: Continue, change the live floor (Carl 60, Donut 10, no potion, an enemy killed, a
##   stone in flight), then pause > Quit Game. The question warns that progress will be lost,
##   with No selected; Escape and No both go back to the pause menu, still paused; Yes closes
##   the game: the process exits with code 0 and prints no engine error or warning;
## - window_close: the same live floor, then the window's close request (as the operating
##   system sends it): the process exits with code 0, no errors.
## After each, the save file is byte for byte the checkpoint, and was not written after the floor
## was entered. This process then does what a fresh launch does: the title describes the
## checkpoint, and Continue restores it (Carl 80, Donut 40, the potion, all three enemies).
## Finally, the helper refuses to run without a save file inside the test folder: pointed at the
## player's save, or given none, it exits with code 2 before doing anything, and the player's
## save (if there is one) keeps its modification time.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_quit_game.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const FLOOR_6_PATH := "res://scenes/levels/floor_06.tscn"
const CHILD_SCRIPT := "res://tests/support/quit_game_child.gd"
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const SLINGSHOT: ActionDefinition = preload("res://resources/actions/slingshot.tres")
const BAT: ActionDefinition = preload("res://resources/actions/baseball_bat.tres")

var _checkpoint_text := ""


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	_seed_floor_6_checkpoint()
	for mode in ["pause_quit", "window_close"]:
		_check_child_session(mode)
		await _check_continue_restores_the_checkpoint(mode)
	_check_child_refuses_other_save_files()
	finish()


func _seed_floor_6_checkpoint() -> void:
	var state := game_state()
	state.start_new_run()
	state.inventory.add(POTION, 1)
	state.inventory.add(SLINGSHOT, 1)
	state.inventory.add(BAT, 1)
	state.action_slots.assign(SLINGSHOT, ActionSlots.SLOT_W)
	state.action_slots.assign(POTION, ActionSlots.SLOT_A)
	state.action_slots.assign(BAT, ActionSlots.SLOT_S)
	state.carl_health = 80
	state.donut_health = 40
	state.record_floor_entry(FLOOR_6_PATH)
	check(save_manager().save_checkpoint(state.floor_entry), "the Floor 6 checkpoint is saved")
	state.start_new_run()
	_checkpoint_text = FileAccess.get_file_as_string(save_manager().save_path)


func _check_child_session(mode: String) -> void:
	print("-- %s: a separate game process" % mode)
	var result := _run_child(["--save=" + save_manager().save_path, "--mode=" + mode])
	var lines: Array = result["lines"]
	check(result["exit_code"] == 0, mode + ": the game process exits with code 0", "exit code %d" % result["exit_code"])
	var problems := lines.filter(func(line: String) -> bool:
		return line.begins_with("ERROR") or line.begins_with("WARNING") or line.begins_with("SCRIPT ERROR") or line.contains("CrashHandler"))
	check(problems.is_empty(), mode + ": no engine error, warning or crash", "\n".join(problems))
	check("CHILD: title says Saved at the start of Floor 6  -  HP 80 / 100" in lines, mode + ": the title offered the Floor 6 checkpoint")
	check("CHILD: entered floor_06.tscn carl=80 donut=40 potions=1" in lines, mode + ": Continue opened Floor 6 with the checkpoint")
	check("CHILD: live carl=60 donut=10 potions=0 enemies=2" in lines, mode + ": the live floor changed (Carl 60, Donut 10, no potion, an enemy killed)")
	if mode == "pause_quit":
		check("CHILD: quit question=Quit game? | Progress since entering this floor will be lost. yes_selected=false" in lines,
				mode + ": Quit Game asks first, warning that progress will be lost, with No selected")
		check("CHILD: after Escape confirming=false open=true paused=true" in lines, mode + ": Escape cancels, back to the pause menu, still paused")
		check("CHILD: after No confirming=false open=true paused=true" in lines, mode + ": No cancels, back to the pause menu, still paused")
		check("CHILD: quitting" in lines, mode + ": Yes was pressed")
	else:
		check("CHILD: closing the window" in lines, mode + ": the window was asked to close")
	check("CHILD: still running" not in lines, mode + ": the process ended on its own")
	check(FileAccess.get_file_as_string(save_manager().save_path) == _checkpoint_text,
			mode + ": the save is still exactly the Floor 6 entry checkpoint (no mid-floor HP, potion or kill)")
	var entry_times := lines.filter(func(line: String) -> bool: return line.begins_with("CHILD: save after entry mtime="))
	var modified_time := FileAccess.get_modified_time(save_manager().save_path)
	check(entry_times.size() == 1 and entry_times[0] == "CHILD: save after entry mtime=%d" % modified_time,
			mode + ": the save file was last written on entering the floor, not on quitting", "%s, now %d" % [entry_times, modified_time])
	if not result["exit_code"] == 0 or not problems.is_empty():
		print("      child output:\n      " + "\n      ".join(lines))


## What a fresh launch after quitting shows: this process has not played yet.
func _check_continue_restores_the_checkpoint(mode: String) -> void:
	var title_path: String = ProjectSettings.get_setting("application/run/main_scene")
	change_scene_to_file(title_path)
	if not await wait_for_scene(title_path):
		return
	var info: String = current_scene.get_node("%SaveInfoLabel").text
	check(info == "Saved at the start of Floor 6  -  HP 80 / 100", mode + ", relaunched: the title describes the checkpoint", info)
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(FLOOR_6_PATH):
		return
	await wait_physics_frames(3)
	var carl: Node2D = current_scene.get_node("Actors/Carl")
	var donut: Node2D = current_scene.get_node("Actors/Donut")
	var enemies := current_scene.get_node("Actors").get_children().filter(func(node: Node) -> bool: return node is Enemy)
	check(carl.health.current_health == 80 and donut.health.current_health == 40 and game_state().inventory.get_quantity(POTION) == 1
			and enemies.size() == 3, mode + ", relaunched: Continue restores Carl 80, Donut 40, the potion and all three enemies",
			"Carl %d, Donut %d, potions %d, enemies %d" % [carl.health.current_health, donut.health.current_health,
			game_state().inventory.get_quantity(POTION), enemies.size()])
	check(current_scene.get_node("HUD/%ActionSlotsLabel").text == "W: Slingshot   A: Potion x1   S: Baseball Bat   D: Fists",
			mode + ", relaunched: the checkpoint's slots")
	change_scene_to_file(title_path)
	await wait_for_scene(title_path)


func _check_child_refuses_other_save_files() -> void:
	print("-- The helper refuses any save file outside the test folder")
	# SaveManager.DEFAULT_SAVE_PATH, read from the script (tests cannot name the autoload's class).
	var player_save: String = save_manager().get_script().get_script_constant_map()["DEFAULT_SAVE_PATH"]
	var player_save_time := FileAccess.get_modified_time(player_save) if FileAccess.file_exists(player_save) else -1
	for arguments: Array in [["--save=" + player_save, "--mode=pause_quit"],
			["--save=user://test_saves/../savegame.json", "--mode=pause_quit"], ["--mode=pause_quit"]]:
		var result := _run_child(arguments)
		var lines: Array = result["lines"]
		check(result["exit_code"] == 2 and lines.any(func(line: String) -> bool: return line.begins_with("CHILD REFUSED"))
				and not lines.any(func(line: String) -> bool: return line.begins_with("CHILD: ")),
				"refused before playing: %s" % " ".join(arguments), "exit code %d" % result["exit_code"])
	var time_after := FileAccess.get_modified_time(player_save) if FileAccess.file_exists(player_save) else -1
	check(time_after == player_save_time, "the player's save (if any) was not touched")


## Runs the helper in its own headless Godot process and returns its exit code and output lines.
func _run_child(user_arguments: Array) -> Dictionary:
	var arguments := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", CHILD_SCRIPT, "--"])
	arguments.append_array(PackedStringArray(user_arguments))
	var output := []
	var exit_code := OS.execute(OS.get_executable_path(), arguments, output, true)
	var lines := Array("\n".join(output).replace("\r", "").split("\n"))
	return {"exit_code": exit_code, "lines": lines}
