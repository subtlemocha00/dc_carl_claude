extends "res://tests/support/game_test.gd"
## Phase 5 end-to-end persistence through the real title screen and levels, on this test's
## own save file. "Quitting" is simulated by going back to the title screen in the same
## process; GameState then still holds the old run, which Continue must fully replace.
## (The real process restart is checked separately; see PROJECT_STATE.md.)
## - No save: Continue is unavailable; New Game needs no confirmation and saves the Surface.
## - Each floor saves its entry checkpoint: Surface -> Floor 1 -> Floor 2, carrying HP,
##   potions and slots. Pickups, potions, damage and death never change the save.
## - Continue restores the floor-entry values (not mid-floor ones), directly on Floor 2 when
##   saved there, with Donut, enemies and pickups as authored.
## - The Phase 4 known issue is fixed: after the last potion empties slot A, a retry gives
##   back the potion and slot A. Repeated deaths never change the checkpoint.
## - New Game over an existing save asks first; No and Escape keep the old save; Yes replaces
##   it with a clean Surface checkpoint.
## - Corrupt or unsupported saves leave Continue unavailable with a message, and New Game can
##   replace them.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_save_game.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const SURFACE_PATH := "res://scenes/levels/surface.tscn"
const FLOOR_1_PATH := "res://scenes/levels/floor_01.tscn"
const FLOOR_2_PATH := "res://scenes/levels/floor_02.tscn"
const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const FLOOR_1_BLOB_SPAWNS := [Vector2(480, 150), Vector2(820, 320)]

var _title_path: String = ProjectSettings.get_setting("application/run/main_scene")


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	if not await _new_game_without_a_save():
		finish()
		return
	if not await _descend_to_floor_1():
		finish()
		return
	await _mid_floor_changes_do_not_save()
	if not await _continue_restores_floor_1_entry():
		finish()
		return
	if not await _descend_to_floor_2():
		finish()
		return
	await _death_and_retry_on_floor_2()
	if not await _continue_on_floor_2():
		finish()
		return
	await _continue_after_death()
	await _new_game_over_an_existing_save()
	await _unloadable_saves()
	finish()


func _new_game_without_a_save() -> bool:
	print("-- No save: New Game")
	# Leave a used run in memory: the new game must not inherit it.
	var state := game_state()
	state.inventory.add(POTION, 3)
	state.action_slots.assign(POTION, ActionSlots.SLOT_W)
	state.carl_health = 30
	if not await _open_title():
		return false
	var title := current_scene
	check(not title.is_continue_available() and _row("%ContinueRow") == "   Continue" and _row("%NewGameRow") == "> New Game",
			"Continue is unavailable and New Game is selected", "%s / %s" % [_row("%ContinueRow"), _row("%NewGameRow")])
	check(_row("%SaveInfoLabel") == "No saved game yet.", "the title says there is no save")
	await tap_key(KEY_UP)
	await tap_key(KEY_DOWN)
	check(_row("%NewGameRow") == "> New Game", "Up/Down cannot select the unavailable Continue")
	await tap_key(KEY_ENTER)
	# Starting the game frees the title screen, so it may only be asked while it still exists.
	check(not (is_instance_valid(title) and title.is_confirming()), "with no save, New Game starts without asking")
	if not await wait_for_scene(SURFACE_PATH):
		return false
	await wait_physics_frames(3)
	_check_save("the Surface checkpoint is saved", "surface", 100, {}, {"action_d": "fists"})
	check(state.inventory.get_quantity(POTION) == 0 and _hud_slots() == "W: —   A: —   S: —   D: Fists"
			and _carl().health.current_health == 100, "the new run is clean: 100 HP, no potions, Fists on D")
	return true


func _descend_to_floor_1() -> bool:
	print("-- Surface -> Floor 1")
	var surface_save := _save_text()
	_carl().health.take_damage(20)
	await wait_physics_frames(3)
	check(_save_text() == surface_save, "taking damage does not write the save")
	await walk_to(current_scene.get_node("Stairs").global_position)
	if not await wait_for_scene(FLOOR_1_PATH):
		return false
	await wait_physics_frames(3)
	_check_save("entering Floor 1 saves its checkpoint (HP 80 carried)", "floor_01", 80, {}, {"action_d": "fists"})
	return true


func _mid_floor_changes_do_not_save() -> void:
	print("-- Floor 1: pickups, slots, damage and potions do not change the save")
	var entry_save := _save_text()
	await walk_to(current_scene.get_node("Pickups/SmallHealthPotions").global_position)
	await wait_physics_frames(2)
	check(game_state().inventory.get_quantity(POTION) == 2, "Carl collects 2 potions")
	await _put_potion_on_a()
	_carl().health.take_damage(50)
	await tap_key(KEY_A)
	check(_carl().health.current_health == 60 and game_state().inventory.get_quantity(POTION) == 1,
			"he takes damage (30 HP) and drinks one (60 HP, x1)")
	check(_save_text() == entry_save, "the save is still the Floor 1 entry checkpoint (80 HP, no potions)")


func _continue_restores_floor_1_entry() -> bool:
	print("-- Quit to the title and Continue on Floor 1")
	if not await _open_title():
		return false
	check(current_scene.is_continue_available() and _row("%ContinueRow") == "> Continue", "Continue is available and selected")
	check(_row("%SaveInfoLabel") == "Saved at the start of Floor 1  -  HP 80 / 100", "the title shows the saved floor and HP",
			_row("%SaveInfoLabel"))
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(FLOOR_1_PATH):
		return false
	await wait_physics_frames(3)
	var state := game_state()
	check(_carl().health.current_health == 80 and state.inventory.get_quantity(POTION) == 0,
			"Continue restores the floor-entry values: 80 HP and 0 potions (not 60 HP and x1)",
			"HP %d, potions %d" % [_carl().health.current_health, state.inventory.get_quantity(POTION)])
	check(_hud_slots() == "W: —   A: —   S: —   D: Fists", "the entry slot layout", _hud_slots())
	check(current_scene.get_node_or_null("Pickups/SmallHealthPotions") != null, "the potion pickup is back")
	var blob_positions := _blobs().map(func(blob: Node2D) -> Vector2: return blob.global_position)
	check(blob_positions == FLOOR_1_BLOB_SPAWNS, "the enemies are back at their spawn points", str(blob_positions))
	_check_donut()
	return true


func _descend_to_floor_2() -> bool:
	print("-- Floor 1 -> Floor 2")
	await walk_to(current_scene.get_node("Pickups/SmallHealthPotions").global_position)
	await wait_physics_frames(2)
	await _put_potion_on_a()
	_carl().health.take_damage(50)
	await tap_key(KEY_A)
	check(_carl().health.current_health == 60 and game_state().inventory.get_quantity(POTION) == 1, "60 HP and one potion left")
	await walk_to(current_scene.get_node("Stairs").global_position)
	if not await wait_for_scene(FLOOR_2_PATH):
		return false
	await wait_physics_frames(3)
	_check_save("entering Floor 2 saves 60 HP, the potion and slot A", "floor_02", 60,
			{"small_health_potion": 1}, {"action_a": "small_health_potion", "action_d": "fists"})
	var exits := current_scene.find_children("*", "", true, false).filter(
			func(node: Node) -> bool: return "destination_scene_path" in node)
	check(exits.is_empty(), "nothing on Floor 2 leads back up")
	return true


func _death_and_retry_on_floor_2() -> void:
	print("-- Floor 2: last potion, death, retry")
	var entry_save := _save_text()
	_carl().health.take_damage(40)
	await tap_key(KEY_A)
	check(game_state().inventory.get_quantity(POTION) == 0 and _hud_slots() == "W: —   A: —   S: —   D: Fists",
			"drinking the last potion empties slot A during play", _hud_slots())
	for attempt in 3:
		var level := current_scene
		var level_id := level.get_instance_id()
		_carl().health.take_damage(1000)
		await wait_physics_frames(2)
		await wait_seconds(1.0)
		check(paused and level.get_node("HUD/%GameOverMessage").visible and current_scene == level,
				"death %d: GAME OVER waits" % (attempt + 1))
		check(_save_text() == entry_save, "death %d: the save still holds the Floor 2 entry checkpoint" % (attempt + 1))
		await tap_key(KEY_ENTER)
		await _wait_for_new_level(level_id)
		check(_carl().health.current_health == 60 and game_state().inventory.get_quantity(POTION) == 1,
				"retry %d: 60 HP and 1 potion, no duplicates" % (attempt + 1),
				"HP %d, potions %d" % [_carl().health.current_health, game_state().inventory.get_quantity(POTION)])
		check(_hud_slots() == "W: —   A: Potion x1   S: —   D: Fists",
				"retry %d: the potion is back on A (Phase 4 known issue fixed)" % (attempt + 1), _hud_slots())
	check(_save_text() == entry_save, "after the retries the save is unchanged")


func _continue_on_floor_2() -> bool:
	print("-- Quit to the title and Continue on Floor 2")
	if not await _open_title():
		return false
	check(_row("%SaveInfoLabel") == "Saved at the start of Floor 2  -  HP 60 / 100", "the title shows Floor 2", _row("%SaveInfoLabel"))
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(FLOOR_2_PATH):
		return false
	await wait_physics_frames(3)
	check(_carl().health.current_health == 60 and game_state().inventory.get_quantity(POTION) == 1,
			"Continue goes straight to Floor 2 with 60 HP and 1 potion")
	check(_hud_slots() == "W: —   A: Potion x1   S: —   D: Fists", "A = potion, D = Fists", _hud_slots())
	check(current_scene.get_node_or_null("Actors/GelatinousBlob") != null, "Floor 2's blob is there")
	_check_donut()
	return true


func _continue_after_death() -> void:
	print("-- Quit at GAME OVER, then Continue")
	_carl().health.take_damage(1000)
	await wait_physics_frames(2)
	# Quitting ends the process; a new one starts unpaused.
	paused = false
	await _open_title()
	check(current_scene.is_continue_available(), "Continue is still available after dying")
	await tap_key(KEY_ENTER)
	await wait_for_scene(FLOOR_2_PATH)
	await wait_physics_frames(3)
	check(_carl().health.current_health == 60 and not paused, "Continue after a death restores the valid checkpoint (60 HP)")


func _new_game_over_an_existing_save() -> void:
	print("-- New Game over an existing save")
	var old_save := _save_text()
	await _open_title()
	var title := current_scene
	await tap_key(KEY_DOWN)
	check(_row("%NewGameRow") == "> New Game", "Down selects New Game")
	await tap_key(KEY_ENTER)
	check(is_instance_valid(title) and title.is_confirming() and title.get_node("%ConfirmPanel").visible and _row("%NoRow") == "> No",
			"New Game asks first, with No selected")
	if not is_instance_valid(title):
		return
	check(_row("%ConfirmQuestion").contains("Existing progress will be replaced."), "the question warns about the save",
			_row("%ConfirmQuestion"))
	await tap_key(KEY_ENTER)
	check(not title.is_confirming() and current_scene == title and _save_text() == old_save, "No keeps the old save")
	await tap_key(KEY_ENTER)
	await tap_key(KEY_ESCAPE)
	check(not title.is_confirming() and current_scene == title and _save_text() == old_save, "Escape also keeps it")
	await tap_key(KEY_ENTER)
	await tap_key(KEY_DOWN)
	check(_row("%YesRow") == "> Yes", "Down selects Yes")
	await tap_key(KEY_ENTER)
	await wait_for_scene(SURFACE_PATH)
	await wait_physics_frames(3)
	_check_save("Yes starts a new game and saves a clean Surface checkpoint", "surface", 100, {}, {"action_d": "fists"})
	check(game_state().inventory.get_quantity(POTION) == 0 and _carl().health.current_health == 100,
			"the new run has none of the old potions or HP")


func _unloadable_saves() -> void:
	print("-- Corrupt and unsupported saves")
	var unsupported: Dictionary = JSON.parse_string(_save_text())
	unsupported["save_version"] = 99
	for bad: String in ["{\"save_version\": 1, \"floor", JSON.stringify(unsupported)]:
		_write_save_file(bad)
		await _open_title()
		var title := current_scene
		check(not title.is_continue_available() and _row("%ContinueRow") == "   Continue" and _row("%NewGameRow") == "> New Game",
				"an unloadable save leaves Continue unavailable")
		check(_row("%SaveInfoLabel") == "Save data could not be loaded.", "the title says the save could not be loaded")
		await tap_key(KEY_ENTER)
		check(is_instance_valid(title) and title.is_confirming() and _row("%ConfirmQuestion").contains("could not be loaded"),
				"New Game still asks before replacing the unloadable file")
		if not is_instance_valid(title):
			return
		await tap_key(KEY_DOWN)
		await tap_key(KEY_ENTER)
		await wait_for_scene(SURFACE_PATH)
		await wait_physics_frames(3)
		check(save_manager().load_checkpoint() != null, "the new game replaced it with a valid save")


## Opens the title screen and waits until it is ready.
func _open_title() -> bool:
	change_scene_to_file(_title_path)
	if not await wait_for_scene(_title_path):
		return false
	await wait_physics_frames(2)
	return true


func _put_potion_on_a() -> void:
	await tap_key(KEY_SPACE)
	await tap_key(KEY_DOWN)
	await tap_key(KEY_A)
	await tap_key(KEY_SPACE)


## Waits until the level with instance id `old_level_id` has been replaced. (The old level is
## freed by then, so only its id is kept.)
func _wait_for_new_level(old_level_id: int) -> void:
	for i in 60:
		if current_scene != null and current_scene.get_instance_id() != old_level_id:
			break
		await physics_frame
	await wait_physics_frames(3)


## Checks the save file against the expected checkpoint. `slots` lists only filled slots.
func _check_save(label: String, floor_id: String, health: int, inventory: Dictionary, slots: Dictionary) -> void:
	var data: Variant = JSON.parse_string(_save_text())
	if not data is Dictionary:
		check(false, label, "the save file is not a JSON object")
		return
	var expected_slots := {"action_w": null, "action_a": null, "action_s": null, "action_d": null}
	expected_slots.merge(slots, true)
	var expected_inventory := {}
	for item_id: String in inventory:
		expected_inventory[item_id] = float(inventory[item_id])
	check(data.get("save_version") == 1 and data.get("floor_id") == floor_id and data["carl"]["health"] == health
			and data["carl"]["max_health"] == 100 and data["inventory"] == expected_inventory and data["action_slots"] == expected_slots,
			label, _save_text().replace("\n", " ").replace("\t", ""))


func _save_text() -> String:
	return FileAccess.get_file_as_string(save_manager().save_path)


func _write_save_file(text: String) -> void:
	var file := FileAccess.open(save_manager().save_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _row(path: String) -> String:
	return (current_scene.get_node(path) as Label).text


func _hud_slots() -> String:
	return current_scene.get_node("HUD/%ActionSlotsLabel").text


func _check_donut() -> void:
	var carl := _carl()
	var donut: CharacterBody2D = current_scene.get_node("Actors/Donut")
	check(donut.follow_target == carl and donut.global_position.distance_to(carl.global_position) < 120.0,
			"Donut arrives with Carl and follows him")


func _carl() -> CharacterBody2D:
	return current_scene.get_node("Actors/Carl")


func _blobs() -> Array:
	return current_scene.get_node("Actors").get_children().filter(
			func(node: Node) -> bool: return node.scene_file_path == "res://scenes/enemies/gelatinous_blob.tscn")
