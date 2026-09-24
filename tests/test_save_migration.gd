extends "res://tests/support/game_test.gd"
## Phase 6: loading Phase 5 saves (save_version 1), on this test's own save file.
## The two fixtures in tests/fixtures/ were written by the Phase 5 game itself (commit fd1d5e7,
## SaveManager.save_checkpoint()), so they are real version 1 files:
##   phase5_save_v1_floor_01.json: Floor 1, 80/100 HP, no items, W = Fists, D empty;
##   phase5_save_v1_floor_02.json: Floor 2, 70/100 HP, 2 potions on S, D = Fists.
## - Both load after Phase 6: floor, HP, potions and slots are kept, and there is no Slingshot.
## - Loading never changes the file.
## - A version 1 save can never own the Slingshot: a Slingshot slot is emptied, an "owned_items"
##   entry is ignored, and a Slingshot with a quantity is rejected.
## - Malformed version 1 data is still rejected, and the file left alone.
## - Version 2 loads normally; a version 2 file without owned_items is rejected; versions 0, 3,
##   999 and -1 are rejected.
## - Through the real title screen: Continue on the version 1 Floor 2 save opens Floor 2 with its
##   state. Entering the floor rewrites the save as version 2 with the same values. The game
##   then plays on: Carl walks, punches, drinks a potion from S and picks up the Slingshot.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_save_migration.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const FIXTURE_FLOOR_1 := "res://tests/fixtures/phase5_save_v1_floor_01.json"
const FIXTURE_FLOOR_2 := "res://tests/fixtures/phase5_save_v1_floor_02.json"
const FLOOR_1_PATH := "res://scenes/levels/floor_01.tscn"
const FLOOR_2_PATH := "res://scenes/levels/floor_02.tscn"
const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const SLINGSHOT: ActionDefinition = preload("res://resources/actions/slingshot.tres")


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	check(save_manager().save_path.begins_with(TEST_SAVE_FOLDER), "the test uses its own save file", save_manager().save_path)
	check(save_manager().SAVE_VERSION == 2, "the game writes save_version 2")
	_check_fixtures_are_version_1()
	_check_fixtures_load()
	_check_version_1_never_owns_reusables()
	_check_malformed_version_1_rejected()
	_check_other_versions()
	await _check_continue_from_version_1()
	finish()


func _check_fixtures_are_version_1() -> void:
	print("-- The fixtures are Phase 5 saves")
	for path: String in [FIXTURE_FLOOR_1, FIXTURE_FLOOR_2]:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		check(data is Dictionary and data.get("save_version") == 1.0 and not data.has("owned_items"),
				"%s: save_version 1, no owned_items" % path.get_file())


func _check_fixtures_load() -> void:
	print("-- Version 1 saves load")
	var text := _write_fixture(FIXTURE_FLOOR_1)
	var loaded: FloorEntry = save_manager().load_checkpoint()
	check(loaded != null and save_manager().last_error == "", "the Floor 1 save loads", save_manager().last_error)
	if loaded != null:
		var inventory := _inventory_of(loaded)
		check(loaded.scene_path == FLOOR_1_PATH and loaded.carl_health == 80 and loaded.carl_max_health == 100,
				"Floor 1, 80 / 100 HP are kept")
		check(inventory.get_actions() == [FISTS] and not inventory.has(SLINGSHOT), "no items, and no Slingshot")
		check(loaded.action_slots == {ActionSlots.SLOT_W: FISTS}, "W = Fists and the empty D are kept", str(loaded.action_slots))
	check(_save_text() == text, "loading did not change the file")

	text = _write_fixture(FIXTURE_FLOOR_2)
	loaded = save_manager().load_checkpoint()
	check(loaded != null and save_manager().last_error == "", "the Floor 2 save loads", save_manager().last_error)
	if loaded != null:
		var inventory := _inventory_of(loaded)
		check(loaded.scene_path == FLOOR_2_PATH and loaded.carl_health == 70 and loaded.carl_max_health == 100,
				"Floor 2, 70 / 100 HP are kept")
		check(inventory.get_quantity(POTION) == 2 and not inventory.has(SLINGSHOT), "2 potions are kept; no Slingshot")
		check(loaded.action_slots == {ActionSlots.SLOT_S: POTION, ActionSlots.SLOT_D: FISTS}, "S = potion and D = Fists are kept",
				str(loaded.action_slots))
	check(_save_text() == text, "loading did not change the file")


func _check_version_1_never_owns_reusables() -> void:
	print("-- A version 1 save never owns the Slingshot")
	var data := _fixture_data(FIXTURE_FLOOR_2)
	data["action_slots"]["action_w"] = "slingshot"
	var loaded := _load_data(data)
	check(loaded != null and not loaded.action_slots.has(ActionSlots.SLOT_W) and loaded.action_slots.get(ActionSlots.SLOT_S) == POTION
			and not _inventory_of(loaded).has(SLINGSHOT), "W = Slingshot in a version 1 save is emptied; the rest is kept")
	data = _fixture_data(FIXTURE_FLOOR_2)
	data["owned_items"] = ["slingshot"]
	data["action_slots"]["action_w"] = "slingshot"
	loaded = _load_data(data)
	check(loaded != null and not _inventory_of(loaded).has(SLINGSHOT) and not loaded.action_slots.has(ActionSlots.SLOT_W),
			"an owned_items entry in a version 1 save is ignored: still no Slingshot")
	data = _fixture_data(FIXTURE_FLOOR_2)
	data["inventory"]["slingshot"] = 1
	_expect_rejected(JSON.stringify(data), "version 1 with a Slingshot quantity")


func _check_malformed_version_1_rejected() -> void:
	print("-- Malformed version 1 saves are still rejected")
	var fixture_text := FileAccess.get_file_as_string(FIXTURE_FLOOR_2)
	_expect_rejected(fixture_text.substr(0, fixture_text.length() >> 1), "truncated version 1 JSON")
	var edits := {
		"HP as a string": func(d: Dictionary) -> void: d["carl"]["health"] = "70",
		"HP 0": func(d: Dictionary) -> void: d["carl"]["health"] = 0,
		"no carl": func(d: Dictionary) -> void: d.erase("carl"),
		"an unknown floor": func(d: Dictionary) -> void: d["floor_id"] = "floor_99",
		"a scene path instead of a floor id": func(d: Dictionary) -> void: d["floor_id"] = FLOOR_2_PATH,
		"a negative quantity": func(d: Dictionary) -> void: d["inventory"]["small_health_potion"] = -2,
		"an unknown item": func(d: Dictionary) -> void: d["inventory"]["mystery_item"] = 1,
		"innate Fists carried": func(d: Dictionary) -> void: d["inventory"]["fists"] = 1,
		"no inventory": func(d: Dictionary) -> void: d.erase("inventory"),
		"no action_slots": func(d: Dictionary) -> void: d.erase("action_slots"),
		"action_slots as a list": func(d: Dictionary) -> void: d["action_slots"] = [],
		"save_version \"1\" as a string": func(d: Dictionary) -> void: d["save_version"] = "1",
	}
	for label: String in edits:
		var data := _fixture_data(FIXTURE_FLOOR_2)
		(edits[label] as Callable).call(data)
		_expect_rejected(JSON.stringify(data), "version 1 with " + label)


func _check_other_versions() -> void:
	print("-- Version 2 loads normally; other versions are rejected")
	var data := _fixture_data(FIXTURE_FLOOR_2)
	data["save_version"] = 2
	data["owned_items"] = ["slingshot"]
	data["action_slots"]["action_w"] = "slingshot"
	var loaded := _load_data(data)
	check(loaded != null and _inventory_of(loaded).has(SLINGSHOT) and loaded.action_slots.get(ActionSlots.SLOT_W) == SLINGSHOT,
			"a version 2 save loads with its owned Slingshot on W", save_manager().last_error)
	data.erase("owned_items")
	_expect_rejected(JSON.stringify(data), "version 2 without owned_items (only version 1 is migrated)")
	for version: int in [0, 3, 999, -1]:
		data = _fixture_data(FIXTURE_FLOOR_2)
		data["save_version"] = version
		_expect_rejected(JSON.stringify(data), "save_version %d" % version)


func _check_continue_from_version_1() -> void:
	print("-- Continue from the version 1 Floor 2 save")
	var fixture_text := _write_fixture(FIXTURE_FLOOR_2)
	var title_path: String = ProjectSettings.get_setting("application/run/main_scene")
	change_scene_to_file(title_path)
	if not await wait_for_scene(title_path):
		return
	await wait_physics_frames(2)
	var info: String = current_scene.get_node("%SaveInfoLabel").text
	check(current_scene.is_continue_available() and info == "Saved at the start of Floor 2  -  HP 70 / 100",
			"the title offers Continue for the version 1 save", info)
	check(_save_text() == fixture_text, "the title screen did not change the file")
	await tap_key(KEY_ENTER)
	if not await wait_for_scene(FLOOR_2_PATH):
		return
	await wait_physics_frames(3)
	var state := game_state()
	var carl: CharacterBody2D = current_scene.get_node("Actors/Carl")
	check(carl.health.current_health == 70 and state.inventory.get_quantity(POTION) == 2 and not state.inventory.has(SLINGSHOT),
			"Continue opens Floor 2 with 70 HP, 2 potions and no Slingshot")
	check(_hud_slots() == "W: —   A: —   S: Potion x2   D: Fists", "the slots are as saved", _hud_slots())
	check(current_scene.get_node_or_null("Pickups/Slingshot") != null, "Floor 2's Slingshot pickup is there")

	var data: Variant = JSON.parse_string(_save_text())
	check(data is Dictionary and data["save_version"] == 2.0 and data["floor_id"] == "floor_02" and data["carl"]["health"] == 70.0
			and data["inventory"] == {"small_health_potion": 2.0} and data["owned_items"] == []
			and data["action_slots"] == {"action_w": null, "action_a": null, "action_s": "small_health_potion", "action_d": "fists"},
			"entering the floor rewrote the save as version 2 with the same values",
			_save_text().replace("\n", " ").replace("\t", ""))
	var migrated_save := _save_text()

	print("-- The migrated game plays on")
	var start := carl.global_position
	await hold_keys([KEY_RIGHT], 20)
	check(carl.global_position.x > start.x + 50.0, "Carl walks")
	var punches := [0]
	(carl.get_action_performer(FISTS) as MeleeAttack).performed.connect(func(_d: Vector2, _h: int) -> void: punches[0] += 1)
	await tap_key(KEY_D)
	check(punches[0] == 1, "D punches")
	await tap_key(KEY_S)
	check(carl.health.current_health == 100 and state.inventory.get_quantity(POTION) == 1, "S drinks a potion: 70 -> 100 HP, x1")
	await walk_to(current_scene.get_node("Pickups/Slingshot").global_position)
	await wait_physics_frames(2)
	check(state.inventory.has(SLINGSHOT), "Carl picks up the Slingshot")
	check(_save_text() == migrated_save, "none of that changed the save")


## Writes a fixture as this test's save file and returns its text.
func _write_fixture(fixture_path: String) -> String:
	var text := FileAccess.get_file_as_string(fixture_path)
	_write_save_file(text)
	return text


## A fixture as JSON data, to edit.
func _fixture_data(fixture_path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(fixture_path))


func _load_data(data: Dictionary) -> FloorEntry:
	_write_save_file(JSON.stringify(data))
	return save_manager().load_checkpoint()


## Writes `text` as the save file and checks that loading rejects it and leaves it alone.
func _expect_rejected(text: String, label: String) -> void:
	_write_save_file(text)
	var loaded: FloorEntry = save_manager().load_checkpoint()
	var reason: String = save_manager().last_error
	check(loaded == null and not reason.is_empty() and _save_text() == text, "rejected: " + label, reason)


func _write_save_file(text: String) -> void:
	DirAccess.make_dir_recursive_absolute(TEST_SAVE_FOLDER)
	var file := FileAccess.open(save_manager().save_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _save_text() -> String:
	return FileAccess.get_file_as_string(save_manager().save_path)


func _inventory_of(checkpoint: FloorEntry) -> Inventory:
	var inventory := Inventory.new()
	inventory.reset([FISTS])
	inventory.restore_snapshot(checkpoint.inventory)
	return inventory


func _hud_slots() -> String:
	return current_scene.get_node("HUD/%ActionSlotsLabel").text
