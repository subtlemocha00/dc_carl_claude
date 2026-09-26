extends "res://tests/support/game_test.gd"
## Phase 11: Quit Game on the title screen, on this test's own save file.
## In this process, through the real title screen and keys:
## - no save: Continue (unavailable), New Game (selected), Settings (Phase 13) and Quit Game; Up/Down
##   go round New Game, Settings and Quit Game only;
## - a Floor 6 save: Continue (selected), New Game, Settings and Quit Game; Up/Down go round all four;
## - New Game over the save still asks first (No selected), and the question's keys do not move
##   the menu's selection;
## - an unloadable save: New Game selected, Quit Game offered, New Game still asks;
## - Floor 6 > pause > Return to Title > Yes: the title offers Quit Game, and Continue still works.
## Quit Game ends the process, so it is pressed in separate Godot processes
## (tests/support/quit_game_child.gd):
## - title_quit with no save file: the process exits with code 0 and no file is created;
## - title_quit with the Floor 6 save: exit code 0, and the file is neither changed nor rewritten;
## - return_title_quit: Continue, the live floor changed, Return to Title, then Quit Game on the
##   title: exit code 0, and the save is still the checkpoint, last written on entering the floor.
## In each, Enter was pressed with Quit Game selected, and the run had not changed (100 HP, no
## potions, no floor entry: the title's cleared GameState).
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_title_quit.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const FLOOR_6_PATH := "res://scenes/levels/floor_06.tscn"
const CHILD_SCRIPT := "res://tests/support/quit_game_child.gd"
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const SLINGSHOT: ActionDefinition = preload("res://resources/actions/slingshot.tres")
const BAT: ActionDefinition = preload("res://resources/actions/baseball_bat.tres")
## The title's options (TitleScreen.Option; test scripts cannot name scene scripts' enums).
const CONTINUE := 0
const NEW_GAME := 1
const SETTINGS := 2
const QUIT := 3

var _title_path: String = ProjectSettings.get_setting("application/run/main_scene")
var _checkpoint_text := ""


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	check(_title_option("CONTINUE") == CONTINUE and _title_option("NEW_GAME") == NEW_GAME and _title_option("SETTINGS") == SETTINGS
			and _title_option("QUIT") == QUIT, "the title's options are Continue, New Game, Settings, Quit Game")
	await _title_without_a_save()
	_quit_from_the_title_without_a_save()
	_seed_floor_6_checkpoint()
	await _title_with_a_save()
	await _new_game_question_still_works()
	_quit_from_the_title_with_a_save()
	_quit_after_return_to_title()
	await _return_to_title_then_continue()
	await _title_with_an_unloadable_save()
	finish()


func _title_without_a_save() -> void:
	print("-- No save")
	check(not FileAccess.file_exists(save_manager().save_path), "there is no save file")
	if not await _open_title():
		return
	check(not _title().is_continue_available() and _rows() == ["   Continue", "> New Game", "   Settings", "   Quit Game"] and _selected() == NEW_GAME,
			"Continue is unavailable, Settings and Quit Game are offered, New Game is selected", str(_rows()))
	check(_row("%SaveInfoLabel") == "No saved game yet.", "the title says there is no save")
	await tap_key(KEY_DOWN)
	check(_selected() == SETTINGS and _rows() == ["   Continue", "   New Game", "> Settings", "   Quit Game"], "Down selects Settings", str(_rows()))
	await tap_key(KEY_DOWN)
	check(_selected() == QUIT and _rows() == ["   Continue", "   New Game", "   Settings", "> Quit Game"], "Down again selects Quit Game", str(_rows()))
	await tap_key(KEY_DOWN)
	check(_selected() == NEW_GAME, "Down again goes round to New Game, past the unavailable Continue")
	await tap_key(KEY_UP)
	check(_selected() == QUIT, "Up from New Game goes round to Quit Game")
	await tap_key(KEY_UP)
	await tap_key(KEY_UP)
	check(_selected() == NEW_GAME and _rows()[0] == "   Continue", "Up twice more: Settings, then New Game; Continue is never selected")


func _quit_from_the_title_without_a_save() -> void:
	print("-- No save: Quit Game in a separate game process")
	var result := _run_child("title_quit")
	var lines: Array = result["lines"]
	_check_clean_exit(result, "title, no save")
	check("CHILD: title says No saved game yet." in lines, "title, no save: the title had no save")
	check("CHILD: title rows Continue | New Game | > Quit Game, Quit Game selected=true" in lines,
			"title, no save: Enter was pressed with Quit Game selected")
	check("CHILD: quitting from the title: carl_health=100 potions=0 floor_entry=<null>" in lines,
			"title, no save: the run was the title's cleared one")
	check(not FileAccess.file_exists(save_manager().save_path), "title, no save: no save file was created")


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


func _title_with_a_save() -> void:
	print("-- A Floor 6 save")
	if not await _open_title():
		return
	check(_title().is_continue_available() and _rows() == ["> Continue", "   New Game", "   Settings", "   Quit Game"] and _selected() == CONTINUE,
			"Continue, New Game, Settings and Quit Game are offered, Continue is selected", str(_rows()))
	check(_row("%SaveInfoLabel") == "Saved at the start of Floor 6  -  HP 80 / 100", "the title describes the save")
	await tap_key(KEY_DOWN)
	check(_selected() == NEW_GAME, "Down selects New Game")
	await tap_key(KEY_DOWN)
	check(_selected() == SETTINGS, "Down again selects Settings")
	await tap_key(KEY_DOWN)
	check(_selected() == QUIT and _rows() == ["   Continue", "   New Game", "   Settings", "> Quit Game"], "Down again selects Quit Game", str(_rows()))
	await tap_key(KEY_DOWN)
	check(_selected() == CONTINUE, "Down again goes round to Continue")
	await tap_key(KEY_UP)
	check(_selected() == QUIT, "Up from Continue goes round to Quit Game")
	await tap_key(KEY_UP)
	check(_selected() == SETTINGS, "Up again selects Settings")
	await tap_key(KEY_UP)
	check(_selected() == NEW_GAME, "Up again selects New Game")


## Starts with New Game selected on the title with the Floor 6 save.
func _new_game_question_still_works() -> void:
	print("-- New Game still asks before replacing the save")
	var title := _title()
	await tap_key(KEY_ENTER)
	check(title.is_confirming() and _row("%NoRow") == "> No" and _row("%ConfirmQuestion").contains("Existing progress will be replaced."),
			"New Game asks first, with No selected")
	check(not _rows().any(func(row: String) -> bool: return row.begins_with(">")), "no menu row is selected while it asks")
	await tap_key(KEY_DOWN)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_UP)
	check(title.is_confirming() and _row("%YesRow") == "> Yes" and _selected() == NEW_GAME,
			"Up/Down in the question choose No or Yes and leave the menu's selection alone")
	await tap_key(KEY_ESCAPE)
	check(not title.is_confirming() and current_scene == title and _selected() == NEW_GAME and _rows()[1] == "> New Game",
			"Escape closes the question, New Game still selected")
	check(FileAccess.get_file_as_string(save_manager().save_path) == _checkpoint_text, "the save is untouched")


func _quit_from_the_title_with_a_save() -> void:
	print("-- A save: Quit Game in a separate game process")
	var modified_time := FileAccess.get_modified_time(save_manager().save_path)
	var result := _run_child("title_quit")
	var lines: Array = result["lines"]
	_check_clean_exit(result, "title, a save")
	check("CHILD: title says Saved at the start of Floor 6  -  HP 80 / 100" in lines, "title, a save: the title offered the Floor 6 save")
	check("CHILD: title rows Continue | New Game | > Quit Game, Quit Game selected=true" in lines,
			"title, a save: Enter was pressed with Quit Game selected")
	check("CHILD: quitting from the title: carl_health=100 potions=0 floor_entry=<null>" in lines,
			"title, a save: the run was the title's cleared one")
	check(FileAccess.get_file_as_string(save_manager().save_path) == _checkpoint_text, "title, a save: the save is byte for byte the same")
	check(FileAccess.get_modified_time(save_manager().save_path) == modified_time, "title, a save: the save file was not rewritten")


func _quit_after_return_to_title() -> void:
	print("-- Floor 6 > Return to Title > Quit Game in a separate game process")
	var result := _run_child("return_title_quit")
	var lines: Array = result["lines"]
	_check_clean_exit(result, "after Return to Title")
	check("CHILD: entered floor_06.tscn carl=80 donut=40 potions=1" in lines, "after Return to Title: Continue opened Floor 6")
	check("CHILD: live carl=60 donut=10 potions=0 enemies=2" in lines, "after Return to Title: the live floor had changed")
	check("CHILD: back on the title, it says Saved at the start of Floor 6  -  HP 80 / 100" in lines,
			"after Return to Title: the title describes the checkpoint, not the live floor")
	check("CHILD: title rows Continue | New Game | > Quit Game, Quit Game selected=true" in lines,
			"after Return to Title: Enter was pressed with Quit Game selected")
	check("CHILD: quitting from the title: carl_health=100 potions=0 floor_entry=<null>" in lines,
			"after Return to Title: the live floor's run was gone (no 60 HP, no floor entry)")
	check(FileAccess.get_file_as_string(save_manager().save_path) == _checkpoint_text,
			"after Return to Title: the save is still exactly the Floor 6 checkpoint")
	var entry_times := lines.filter(func(line: String) -> bool: return line.begins_with("CHILD: save after entry mtime="))
	var modified_time := FileAccess.get_modified_time(save_manager().save_path)
	check(entry_times.size() == 1 and entry_times[0] == "CHILD: save after entry mtime=%d" % modified_time,
			"after Return to Title: the save was last written on entering the floor", "%s, now %d" % [entry_times, modified_time])


## Same process: Floor 6 > Return to Title > Yes, Quit Game is offered, then Continue still works.
func _return_to_title_then_continue() -> void:
	print("-- Floor 6 > Return to Title > Continue, in this process")
	if not await _open_title():
		return
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(FLOOR_6_PATH):
		return
	await wait_physics_frames(3)
	current_scene.get_node("Actors/Carl").health.take_damage(50)
	# Pause > Return to Title (past Settings) > Yes.
	await tap_key(KEY_ESCAPE)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(_title_path):
		return
	check(_rows() == ["> Continue", "   New Game", "   Settings", "   Quit Game"] and _row("%SaveInfoLabel") == "Saved at the start of Floor 6  -  HP 80 / 100",
			"back on the title: Continue selected, Settings and Quit Game offered, the checkpoint described", str(_rows()))
	await tap_key(KEY_DOWN)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_DOWN)
	check(_selected() == QUIT, "Quit Game can be selected")
	await tap_key(KEY_DOWN)
	check(_selected() == CONTINUE, "and Down goes round to Continue")
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(FLOOR_6_PATH):
		return
	await wait_physics_frames(3)
	var enemies := current_scene.get_node("Actors").get_children().filter(func(node: Node) -> bool: return node is Enemy)
	check(current_scene.get_node("Actors/Carl").health.current_health == 80 and current_scene.get_node("Actors/Donut").health.current_health == 40
			and game_state().inventory.get_quantity(POTION) == 1 and enemies.size() == 3,
			"Continue restores the checkpoint (Carl 80, Donut 40, the potion, three enemies)")
	check(FileAccess.get_file_as_string(save_manager().save_path) == _checkpoint_text, "the save is still the checkpoint")


func _title_with_an_unloadable_save() -> void:
	print("-- An unloadable save")
	var file := FileAccess.open(save_manager().save_path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	if not await _open_title():
		return
	var title := _title()
	check(not title.is_continue_available() and _rows() == ["   Continue", "> New Game", "   Settings", "   Quit Game"],
			"Continue is unavailable, New Game is selected, Settings and Quit Game are offered", str(_rows()))
	check(_row("%SaveInfoLabel") == "Save data could not be loaded.", "the title says the save could not be loaded")
	await tap_key(KEY_DOWN)
	await tap_key(KEY_DOWN)
	check(_selected() == QUIT, "Down twice selects Quit Game")
	await tap_key(KEY_DOWN)
	await tap_key(KEY_ENTER)
	check(title.is_confirming() and _row("%ConfirmQuestion").contains("could not be loaded"), "New Game still asks before replacing the file")
	await tap_key(KEY_ESCAPE)
	check(not title.is_confirming() and FileAccess.get_file_as_string(save_manager().save_path) == "{broken", "Escape keeps the file")


func _check_clean_exit(result: Dictionary, label: String) -> void:
	var lines: Array = result["lines"]
	check(result["exit_code"] == 0, label + ": the game process exits with code 0", "exit code %d" % result["exit_code"])
	var problems := lines.filter(func(line: String) -> bool:
		return line.begins_with("ERROR") or line.begins_with("WARNING") or line.begins_with("SCRIPT ERROR") or line.contains("CrashHandler"))
	check(problems.is_empty(), label + ": no engine error, warning or crash", "\n".join(problems))
	check("CHILD: still running" not in lines, label + ": the process ended on its own")
	if result["exit_code"] != 0 or not problems.is_empty():
		print("      child output:\n      " + "\n      ".join(lines))


## Runs quit_game_child.gd on this test's save file in its own headless Godot process.
func _run_child(mode: String) -> Dictionary:
	var arguments := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", CHILD_SCRIPT, "--",
			"--save=" + save_manager().save_path, "--mode=" + mode])
	var output := []
	var exit_code := OS.execute(OS.get_executable_path(), arguments, output, true)
	return {"exit_code": exit_code, "lines": Array("\n".join(output).replace("\r", "").split("\n"))}


func _open_title() -> bool:
	change_scene_to_file(_title_path)
	return await wait_for_scene(_title_path)


func _title() -> Node:
	return current_scene


func _title_option(option_name: String) -> int:
	var script: Script = load("res://scripts/ui/title_screen.gd")
	return script.get_script_constant_map()["Option"][option_name]


func _selected() -> int:
	return _title().get_selected_option()


func _row(row_name: String) -> String:
	return (_title().get_node(row_name) as Label).text


func _rows() -> Array:
	return ["%ContinueRow", "%NewGameRow", "%SettingsRow", "%QuitRow"].map(func(row_name: String) -> String: return _row(row_name))
