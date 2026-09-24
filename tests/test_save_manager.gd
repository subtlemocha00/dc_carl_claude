extends "res://tests/support/game_test.gd"
## Phase 5-6 SaveManager checks, on this test's own save file (never the player's):
## - the registries: every floor and action id maps back to itself, and the known floors are
##   exactly surface, floor_01, floor_02 and floor_03;
## - a checkpoint is written as JSON (save_version 2) with stable ids only, and loads back
##   unchanged; a Floor 3 checkpoint keeps the owned Slingshot in owned_items, with no
##   quantity; a new save replaces the old one and leaves no temporary file;
## - untrusted data is rejected without a crash or an engine error: malformed JSON, wrong
##   root type, unsupported or missing version, missing fields, unknown floor (or a scene
##   path instead of an id), bad HP, negative/fractional/string quantities, unknown or innate
##   items, a reusable item with a quantity, bad owned_items (not a list, unknown, not a
##   string, consumable, innate, listed twice), and a wrong slot structure. A rejected file is
##   left untouched;
## - slots are sanitized, the rest of the save kept: unknown actions, items Carl would not
##   have (a potion with none left, a Slingshot he does not own), and one action in two slots;
## - deleting works with and without a save, and a save interrupted before its final rename
##   is still found.
## Loading version 1 saves (migration) is covered by test_save_migration.gd.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_save_manager.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const SLINGSHOT: ActionDefinition = preload("res://resources/actions/slingshot.tres")
const FLOOR_2_PATH := "res://scenes/levels/floor_02.tscn"
const FLOOR_3_PATH := "res://scenes/levels/floor_03.tscn"


func _initialize() -> void:
	_run_checks.call_deferred()


func _run_checks() -> void:
	check(save_manager().save_path.begins_with(TEST_SAVE_FOLDER), "the test uses its own save file", save_manager().save_path)
	_check_registries()
	_check_round_trip()
	_check_rejected_data()
	_check_sanitized_slots()
	_check_delete_and_recovery()
	finish()


func _check_registries() -> void:
	print("-- Registries")
	for action_id: StringName in ActionRegistry.ACTIONS:
		check(ActionRegistry.find(action_id).id == action_id, "action '%s' is registered under its own id" % action_id)
	check(ActionRegistry.find(&"laser_sword") == null, "an unknown action id finds nothing")
	for floor_id: StringName in FloorRegistry.FLOORS:
		var scene_path := FloorRegistry.get_scene_path(floor_id)
		check(ResourceLoader.exists(scene_path) and FloorRegistry.get_floor_id(scene_path) == floor_id,
				"floor '%s' maps to an existing scene and back" % floor_id)
	check(FloorRegistry.get_scene_path(&"floor_99") == "" and not FloorRegistry.has_floor(&"floor_99"), "an unknown floor has no scene")
	check(FloorRegistry.FLOORS.keys() == [&"surface", &"floor_01", &"floor_02", &"floor_03"],
			"the known floors are surface, floor_01, floor_02 and floor_03", str(FloorRegistry.FLOORS.keys()))


func _check_round_trip() -> void:
	print("-- Writing and reading a checkpoint")
	var saves := save_manager()
	check(not saves.has_save_file() and saves.load_checkpoint() == null, "at first there is no save")
	check(saves.save_checkpoint(_floor_2_checkpoint()), "a Floor 2 checkpoint is saved")
	check(FileAccess.file_exists(saves.save_path) and not FileAccess.file_exists(saves.save_path + ".tmp"),
			"the save file exists and no temporary file is left")
	var text := FileAccess.get_file_as_string(saves.save_path)
	var data: Variant = JSON.parse_string(text)
	check(data is Dictionary and data["save_version"] == 2, "the file is JSON with save_version 2")
	check(data["floor_id"] == "floor_02" and data["carl"]["health"] == 90 and data["carl"]["max_health"] == 100,
			"it stores the floor id and Carl's HP")
	check(data["inventory"] == {"small_health_potion": 1.0}, "it stores item quantities by id", str(data["inventory"]))
	check(data["owned_items"] == [], "it stores an empty owned_items list when Carl owns no reusable item", str(data.get("owned_items")))
	check(data["action_slots"] == {"action_w": null, "action_a": "small_health_potion", "action_s": null, "action_d": "fists"},
			"it stores the four slots as action ids or null", str(data["action_slots"]))
	check(not text.contains("res://") and not text.contains("Object"), "no scene paths or objects are written")

	var loaded: FloorEntry = saves.load_checkpoint()
	check(loaded != null and saves.last_error == "", "the checkpoint loads", saves.last_error)
	if loaded != null:
		check(loaded.scene_path == FLOOR_2_PATH and loaded.carl_health == 90 and loaded.carl_max_health == 100,
				"floor and HP come back")
		check(_quantity(loaded, POTION) == 1, "the potion quantity comes back")
		check(loaded.action_slots == {ActionSlots.SLOT_A: POTION, ActionSlots.SLOT_D: FISTS}, "the slot layout comes back",
				str(loaded.action_slots))

	print("-- A Floor 3 checkpoint with the Slingshot")
	check(saves.save_checkpoint(_floor_3_checkpoint()), "a Floor 3 checkpoint is saved")
	data = JSON.parse_string(FileAccess.get_file_as_string(saves.save_path))
	check(data["save_version"] == 2 and data["floor_id"] == "floor_03" and data["carl"]["health"] == 80,
			"it stores floor_03 and 80 HP")
	check(data["owned_items"] == ["slingshot"] and data["inventory"] == {"small_health_potion": 1.0},
			"the Slingshot is stored as an owned item, with no quantity; the potion keeps its quantity",
			"%s / %s" % [data["owned_items"], data["inventory"]])
	check(data["action_slots"] == {"action_w": "slingshot", "action_a": "small_health_potion", "action_s": null, "action_d": "fists"},
			"W = Slingshot is stored", str(data["action_slots"]))
	loaded = saves.load_checkpoint()
	check(loaded != null and loaded.scene_path == FLOOR_3_PATH, "the Floor 3 checkpoint loads", saves.last_error)
	if loaded != null:
		var inventory := Inventory.new()
		inventory.restore_snapshot(loaded.inventory)
		check(inventory.has(SLINGSHOT) and inventory.get_quantity(SLINGSHOT) == 0 and inventory.get_quantity(POTION) == 1,
				"the loaded inventory owns the Slingshot (no quantity) and has 1 potion")
		check(loaded.action_slots == {ActionSlots.SLOT_W: SLINGSHOT, ActionSlots.SLOT_A: POTION, ActionSlots.SLOT_D: FISTS},
				"the loaded layout has W = Slingshot, A = potion, D = Fists", str(loaded.action_slots))

	var surface := _floor_2_checkpoint()
	surface.scene_path = FloorRegistry.get_scene_path(&"surface")
	saves.save_checkpoint(surface)
	check(saves.load_checkpoint().scene_path == surface.scene_path, "a new save replaces the old one")


func _check_rejected_data() -> void:
	print("-- Untrusted data is rejected safely")
	var cases := {
		"malformed JSON": "{\"save_version\": 1, \"floor_id\": ",
		"an empty file": "",
		"a JSON array": "[1, 2, 3]",
		"a JSON string": "\"floor_02\"",
	}
	for label: String in cases:
		_expect_rejected(cases[label], label)
	var edits := {
		"unsupported save_version 3": func(d: Dictionary) -> void: d["save_version"] = 3,
		"unsupported save_version 999": func(d: Dictionary) -> void: d["save_version"] = 999,
		"save_version 0": func(d: Dictionary) -> void: d["save_version"] = 0,
		"save_version as a string": func(d: Dictionary) -> void: d["save_version"] = "1",
		"no save_version": func(d: Dictionary) -> void: d.erase("save_version"),
		"no floor_id": func(d: Dictionary) -> void: d.erase("floor_id"),
		"an unknown floor": func(d: Dictionary) -> void: d["floor_id"] = "floor_99",
		"a scene path instead of a floor id": func(d: Dictionary) -> void: d["floor_id"] = FLOOR_2_PATH,
		"no carl": func(d: Dictionary) -> void: d.erase("carl"),
		"HP as a string": func(d: Dictionary) -> void: d["carl"]["health"] = "90",
		"HP 0": func(d: Dictionary) -> void: d["carl"]["health"] = 0,
		"HP above max": func(d: Dictionary) -> void: d["carl"]["health"] = 101,
		"fractional HP": func(d: Dictionary) -> void: d["carl"]["health"] = 90.5,
		"max HP 0": func(d: Dictionary) -> void: d["carl"]["max_health"] = 0,
		"no inventory": func(d: Dictionary) -> void: d.erase("inventory"),
		"inventory as a list": func(d: Dictionary) -> void: d["inventory"] = [],
		"a negative quantity": func(d: Dictionary) -> void: d["inventory"]["small_health_potion"] = -1,
		"a fractional quantity": func(d: Dictionary) -> void: d["inventory"]["small_health_potion"] = 1.5,
		"a quantity as a string": func(d: Dictionary) -> void: d["inventory"]["small_health_potion"] = "2",
		"an unknown item": func(d: Dictionary) -> void: d["inventory"]["mystery_item"] = 1,
		"innate Fists carried as an item": func(d: Dictionary) -> void: d["inventory"]["fists"] = 1,
		"the reusable Slingshot with a quantity": func(d: Dictionary) -> void: d["inventory"]["slingshot"] = 1,
		"no owned_items": func(d: Dictionary) -> void: d.erase("owned_items"),
		"owned_items as an object": func(d: Dictionary) -> void: d["owned_items"] = {"slingshot": 1},
		"owned_items as a string": func(d: Dictionary) -> void: d["owned_items"] = "slingshot",
		"an unknown owned item": func(d: Dictionary) -> void: d["owned_items"] = ["laser_sword"],
		"a scene path as an owned item": func(d: Dictionary) -> void: d["owned_items"] = ["res://scenes/actions/slingshot.tscn"],
		"an owned item that is a number": func(d: Dictionary) -> void: d["owned_items"] = [5],
		"a consumable in owned_items": func(d: Dictionary) -> void: d["owned_items"] = ["small_health_potion"],
		"innate Fists in owned_items": func(d: Dictionary) -> void: d["owned_items"] = ["fists"],
		"an owned item listed twice": func(d: Dictionary) -> void: d["owned_items"] = ["slingshot", "slingshot"],
		"no action_slots": func(d: Dictionary) -> void: d.erase("action_slots"),
		"action_slots as a list": func(d: Dictionary) -> void: d["action_slots"] = [],
		"a missing slot": func(d: Dictionary) -> void: d["action_slots"].erase("action_d"),
		"an unknown slot": func(d: Dictionary) -> void: d["action_slots"]["action_x"] = null,
		"a slot holding a number": func(d: Dictionary) -> void: d["action_slots"]["action_w"] = 5,
	}
	for label: String in edits:
		var data := _valid_data()
		(edits[label] as Callable).call(data)
		_expect_rejected(JSON.stringify(data), label)


## Writes `text` as the save file and checks that loading rejects it and leaves it alone.
func _expect_rejected(text: String, label: String) -> void:
	_write_save_file(text)
	var loaded: FloorEntry = save_manager().load_checkpoint()
	var reason: String = save_manager().last_error
	check(loaded == null and not reason.is_empty() and FileAccess.get_file_as_string(save_manager().save_path) == text,
			"rejected: " + label, reason)


func _check_sanitized_slots() -> void:
	print("-- Slots are sanitized, the rest of the save is kept")
	var data := _valid_data()
	data["action_slots"]["action_a"] = "laser_sword"
	var loaded := _load_data(data)
	check(loaded != null and not loaded.action_slots.has(ActionSlots.SLOT_A) and loaded.action_slots.get(ActionSlots.SLOT_D) == FISTS,
			"an unknown action in a slot leaves that slot empty")
	data = _valid_data()
	data["inventory"] = {}
	loaded = _load_data(data)
	check(loaded != null and not loaded.action_slots.has(ActionSlots.SLOT_A) and _quantity(loaded, POTION) == 0,
			"a potion slot without potions is emptied")
	data = _valid_data()
	data["inventory"] = {"small_health_potion": 0}
	loaded = _load_data(data)
	check(loaded != null and _quantity(loaded, POTION) == 0 and not loaded.action_slots.has(ActionSlots.SLOT_A),
			"a quantity of 0 means no potions")
	data = _valid_data()
	data["action_slots"]["action_w"] = "fists"
	loaded = _load_data(data)
	check(loaded != null and loaded.action_slots.values().count(FISTS) == 1 and loaded.action_slots.get(ActionSlots.SLOT_W) == FISTS,
			"an action named in two slots keeps only the first", str(loaded.action_slots) if loaded != null else "not loaded")
	data = _valid_data()
	data["action_slots"]["action_w"] = "slingshot"
	loaded = _load_data(data)
	check(loaded != null and not loaded.action_slots.has(ActionSlots.SLOT_W) and loaded.action_slots.get(ActionSlots.SLOT_A) == POTION,
			"a Slingshot slot without owning the Slingshot is emptied, the rest is kept")
	data["owned_items"] = ["slingshot"]
	loaded = _load_data(data)
	check(loaded != null and loaded.action_slots.get(ActionSlots.SLOT_W) == SLINGSHOT, "with the Slingshot owned, W = Slingshot is kept")
	data = _valid_data()
	data["carl"]["health"] = 90.0
	check(_load_data(data) != null, "whole numbers written as 90.0 are accepted")


func _check_delete_and_recovery() -> void:
	print("-- Deleting, and a save interrupted before its final rename")
	var saves := save_manager()
	saves.delete_save()
	check(not saves.has_save_file(), "delete_save removes the save")
	saves.delete_save()
	check(not saves.has_save_file(), "delete_save with no save does nothing (and logs nothing)")
	var temp_path: String = saves.save_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(_valid_data()))
	file.close()
	var loaded: FloorEntry = saves.load_checkpoint()
	check(saves.has_save_file() and loaded != null and loaded.scene_path == FLOOR_2_PATH,
			"a finished temporary file left by an interrupted save still loads")
	check(saves.save_checkpoint(_floor_2_checkpoint()) and not FileAccess.file_exists(temp_path),
			"the next save replaces it cleanly")
	file = FileAccess.open(temp_path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	check(saves.load_checkpoint() != null, "a broken temporary file next to a good save is ignored")
	saves.delete_save()
	check(not FileAccess.file_exists(temp_path) and not FileAccess.file_exists(saves.save_path), "delete_save removes both files")


## A Floor 2 checkpoint: 90/100 HP, 1 potion on A, Fists on D.
func _floor_2_checkpoint() -> FloorEntry:
	var inventory := Inventory.new()
	inventory.reset([FISTS])
	inventory.add(POTION, 1)
	var checkpoint := FloorEntry.new()
	checkpoint.scene_path = FLOOR_2_PATH
	checkpoint.carl_health = 90
	checkpoint.carl_max_health = 100
	checkpoint.inventory = inventory.get_snapshot()
	checkpoint.action_slots = {ActionSlots.SLOT_A: POTION, ActionSlots.SLOT_D: FISTS}
	return checkpoint


## A Floor 3 checkpoint: 80/100 HP, 1 potion on A, the Slingshot owned and on W, Fists on D.
func _floor_3_checkpoint() -> FloorEntry:
	var inventory := Inventory.new()
	inventory.reset([FISTS])
	inventory.add(POTION, 1)
	inventory.add(SLINGSHOT, 1)
	var checkpoint := FloorEntry.new()
	checkpoint.scene_path = FLOOR_3_PATH
	checkpoint.carl_health = 80
	checkpoint.carl_max_health = 100
	checkpoint.inventory = inventory.get_snapshot()
	checkpoint.action_slots = {ActionSlots.SLOT_W: SLINGSHOT, ActionSlots.SLOT_A: POTION, ActionSlots.SLOT_D: FISTS}
	return checkpoint


## The save data of _floor_2_checkpoint(), as it would be read from JSON.
func _valid_data() -> Dictionary:
	return JSON.parse_string(JSON.stringify(save_manager().encode(_floor_2_checkpoint())))


func _load_data(data: Dictionary) -> FloorEntry:
	_write_save_file(JSON.stringify(data))
	return save_manager().load_checkpoint()


func _write_save_file(text: String) -> void:
	DirAccess.make_dir_recursive_absolute(TEST_SAVE_FOLDER)
	var file := FileAccess.open(save_manager().save_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _quantity(checkpoint: FloorEntry, item: ActionDefinition) -> int:
	var inventory := Inventory.new()
	inventory.restore_snapshot(checkpoint.inventory)
	return inventory.get_quantity(item)
