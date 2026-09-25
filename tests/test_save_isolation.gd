extends "res://tests/support/game_test.gd"
## Phase 8: tests and tools can never read or write the player's save.
## A test run (started with a script, like every test) may only use save files inside
## SaveManager.TEST_SAVE_FOLDER (user://test_saves/). Everything else, the player's
## user://savegame.json above all, is refused with an engine error (which fails a test) instead
## of being used. This test checks that:
## - the rule itself: the player's save path, paths that only look like test paths
##   ("user://test_saves/../savegame.json", "user://test_saves_old/...") and other files are
##   refused; files inside the folder are allowed; the tests' folder is SaveManager's;
## - a stray file outside the folder is neither written, loaded nor deleted, and each refusal is
##   reported;
## - pointed at the player's save, SaveManager finds no save, loads nothing and refuses to write
##   one, and a level that starts in that state saves nothing: the player's save (if there is one)
##   is not touched. Its existence and modification time are compared, never its content.
## For safety this test only tries to write the player's save path after SaveManager has
## refused the same kind of call on a stray file, and never calls delete_save() on it.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_save_isolation.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const PLAYER_SAVE := "user://savegame.json"
const STRAY_SAVE := "user://not_a_test_save.json"
const FLOOR_1_PATH := "res://scenes/levels/floor_01.tscn"
const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	var saves := save_manager()
	var own_path: String = saves.save_path
	check(own_path == TEST_SAVE_FOLDER + "test_save_isolation.json" and TEST_SAVE_FOLDER == saves.TEST_SAVE_FOLDER,
			"the test uses its own file in SaveManager's test folder", own_path)
	check(saves.DEFAULT_SAVE_PATH == PLAYER_SAVE, "the player's save is user://savegame.json")
	_check_rule()
	var stray_refused := _check_stray_file_refused()
	if stray_refused:
		await _check_player_save_untouched()
	else:
		check(false, "SaveManager wrote a stray file, so this test does not go near the player's save")
	saves.save_path = own_path
	check(saves.save_checkpoint(_checkpoint()) and saves.load_checkpoint() != null, "the test's own file still works")
	finish()


func _check_rule() -> void:
	print("-- Which paths a test run may use")
	var saves := save_manager()
	var cases := {
		PLAYER_SAVE: false,
		"user://test_saves/../savegame.json": false,
		"user://test_saves_old/savegame.json": false,
		"user://savegame.json.tmp": false,
		STRAY_SAVE: false,
		"res://savegame.json": false,
		TEST_SAVE_FOLDER + "some_test.json": true,
		TEST_SAVE_FOLDER + "sub/folder/some_test.json": true,
	}
	for path: String in cases:
		check(saves.is_save_path_allowed(path) == cases[path], "%s %s" % [path, "is allowed" if cases[path] else "is refused"])


## Returns true only if SaveManager refused to write, read and delete a stray file outside the
## test folder (so it is safe to point it at the player's save afterwards).
func _check_stray_file_refused() -> bool:
	print("-- A stray file outside the test folder")
	var saves := save_manager()
	DirAccess.remove_absolute(STRAY_SAVE)
	saves.save_path = STRAY_SAVE
	var saved: bool = saves.save_checkpoint(_checkpoint())
	var written := FileAccess.file_exists(STRAY_SAVE)
	check(not saved and not written, "save_checkpoint() refuses it and writes nothing")
	_expect_refusals(1, "the refused save is reported")
	if written:
		DirAccess.remove_absolute(STRAY_SAVE)
		return false

	# A stray file that already exists: not found, not loaded, not deleted.
	var file := FileAccess.open(STRAY_SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(saves.encode(_checkpoint())))
	file.close()
	check(not saves.has_save_file() and saves.load_checkpoint() == null, "an existing stray file is not seen or loaded")
	saves.delete_save()
	check(FileAccess.file_exists(STRAY_SAVE), "delete_save() refuses to delete it")
	_expect_refusals(3, "each refusal (has_save_file, load_checkpoint, delete_save) is reported")
	DirAccess.remove_absolute(STRAY_SAVE)
	return not written


func _check_player_save_untouched() -> void:
	print("-- The player's save")
	var saves := save_manager()
	var existed_before := FileAccess.file_exists(PLAYER_SAVE)
	var modified_before := FileAccess.get_modified_time(PLAYER_SAVE) if existed_before else 0
	var temp_existed_before := FileAccess.file_exists(PLAYER_SAVE + ".tmp")
	saves.save_path = PLAYER_SAVE
	check(not saves.has_save_file() and saves.load_checkpoint() == null,
			"pointed at the player's save, a test run finds no save and loads nothing (whether or not the player has one)")
	check(saves.last_error != "", "load_checkpoint() gives a reason", saves.last_error)
	check(not saves.save_checkpoint(_checkpoint()), "save_checkpoint() refuses to write the player's save")
	_expect_refusals(3, "each refusal is reported as an error, never silent")

	# A level starting in that state: it cannot save its checkpoint.
	game_state().start_new_run()
	change_scene_to_file(FLOOR_1_PATH)
	await wait_for_scene(FLOOR_1_PATH)
	await wait_physics_frames(3)
	_expect_refusals(1, "a level that starts while SaveManager points at the player's save cannot save its checkpoint")
	check(FileAccess.file_exists(PLAYER_SAVE) == existed_before and FileAccess.file_exists(PLAYER_SAVE + ".tmp") == temp_existed_before
			and (not existed_before or FileAccess.get_modified_time(PLAYER_SAVE) == modified_before),
			"the player's save is exactly as it was: %s" % ("same file, same modification time" if existed_before else "there is still none"))
	current_scene.queue_free()
	await process_frame


## Checks that exactly `count` refusals were reported since the last call, and nothing else.
func _expect_refusals(count: int, label: String) -> void:
	var messages := take_engine_messages()
	var refusals := Array(messages).filter(func(message: String) -> bool: return message.begins_with("SaveManager refused to use"))
	check(refusals.size() == count and messages.size() == count, label, str(messages))


func _checkpoint() -> FloorEntry:
	var checkpoint := FloorEntry.new()
	checkpoint.scene_path = FLOOR_1_PATH
	checkpoint.carl_health = 100
	checkpoint.carl_max_health = 100
	checkpoint.donut_health = 60
	checkpoint.donut_max_health = 60
	var inventory := Inventory.new()
	inventory.reset([FISTS])
	checkpoint.inventory = inventory.get_snapshot()
	checkpoint.action_slots = {ActionSlots.SLOT_D: FISTS}
	return checkpoint
