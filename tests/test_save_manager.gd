extends "res://tests/support/game_test.gd"
## Phase 5-9 SaveManager checks, on this test's own save file (never the player's):
## - the registries: every floor and action id maps back to itself, the known floors are
##   exactly surface and floor_01 to floor_06 (Phase 9), and the known actions are Fists, the
##   potion, the Slingshot and (Phase 9) the Baseball Bat;
## - a checkpoint is written as JSON (save_version 3, Phase 8) with stable ids only, and loads
##   back unchanged, Donut's HP included; a Floor 3 checkpoint keeps the owned Slingshot in
##   owned_items, with no quantity; Floor 4 and Floor 5 checkpoints are written the same way;
##   Donut at 0 HP (downed) is saved and loaded as 0; a new save replaces the old one and leaves
##   no temporary file;
## - Phase 9: a Floor 6 checkpoint owning the Baseball Bat (on S) and the Slingshot is still
##   save_version 3, with exactly the same fields: the Bat is just one more owned_items id. It
##   loads back with both owned and S = Baseball Bat. A Bat with a quantity, listed twice, or on
##   a slot without being owned is handled like the Slingshot (rejected / slot emptied);
## - untrusted data is rejected without a crash or an engine error: malformed JSON, wrong
##   root type, unsupported or missing version, missing fields, unknown floor (or a scene
##   path instead of an id), bad HP, bad Donut data (missing, not an object, negative, above
##   her maximum, fractional, a string, a bad maximum), negative/fractional/string quantities,
##   unknown or innate items, a reusable item with a quantity, bad owned_items (not a list,
##   unknown, not a string, consumable, innate, listed twice), and a wrong slot structure. A
##   rejected file is left untouched;
## - slots are sanitized, the rest of the save kept: unknown actions, items Carl would not
##   have (a potion with none left, a Slingshot he does not own), and one action in two slots;
## - deleting works with and without a save, and a save interrupted before its final rename
##   is still found.
## Loading version 1 and 2 saves (migration) is covered by test_save_migration.gd, and the
## rule that tests can never use the player's save by test_save_isolation.gd.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/test_save_manager.gd
##
## Exits with code 0 when every check passes and 1 otherwise.

const FISTS: ActionDefinition = preload("res://resources/actions/fists.tres")
const POTION: ActionDefinition = preload("res://resources/actions/small_health_potion.tres")
const SLINGSHOT: ActionDefinition = preload("res://resources/actions/slingshot.tres")
const BAT: ActionDefinition = preload("res://resources/actions/baseball_bat.tres")
const FLOOR_2_PATH := "res://scenes/levels/floor_02.tscn"
const FLOOR_3_PATH := "res://scenes/levels/floor_03.tscn"
const FLOOR_4_PATH := "res://scenes/levels/floor_04.tscn"
const FLOOR_5_PATH := "res://scenes/levels/floor_05.tscn"
const FLOOR_6_PATH := "res://scenes/levels/floor_06.tscn"


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
	check(ActionRegistry.ACTIONS.keys() == [&"fists", &"small_health_potion", &"slingshot", &"baseball_bat"],
			"the known actions are fists, small_health_potion, slingshot and (Phase 9) baseball_bat", str(ActionRegistry.ACTIONS.keys()))
	check(ActionRegistry.find(&"baseball_bat") == BAT and not BAT.consumable and BAT.assignable,
			"baseball_bat is the reusable, assignable Baseball Bat")
	for floor_id: StringName in FloorRegistry.FLOORS:
		var scene_path := FloorRegistry.get_scene_path(floor_id)
		check(ResourceLoader.exists(scene_path) and FloorRegistry.get_floor_id(scene_path) == floor_id,
				"floor '%s' maps to an existing scene and back" % floor_id)
	check(FloorRegistry.get_scene_path(&"floor_99") == "" and not FloorRegistry.has_floor(&"floor_99"), "an unknown floor has no scene")
	check(FloorRegistry.FLOORS.keys() == [&"surface", &"floor_01", &"floor_02", &"floor_03", &"floor_04", &"floor_05", &"floor_06"],
			"the known floors are surface and floor_01 to floor_06", str(FloorRegistry.FLOORS.keys()))
	check(FloorRegistry.get_display_name(&"floor_04") == "Floor 4", "floor_04 is shown as 'Floor 4'")
	check(FloorRegistry.get_display_name(&"floor_05") == "Floor 5" and FloorRegistry.get_scene_path(&"floor_05") == FLOOR_5_PATH,
			"floor_05 is shown as 'Floor 5' and opens floor_05.tscn")
	check(FloorRegistry.get_display_name(&"floor_06") == "Floor 6" and FloorRegistry.get_scene_path(&"floor_06") == FLOOR_6_PATH,
			"floor_06 (Phase 9) is shown as 'Floor 6' and opens floor_06.tscn")
	check(not FloorRegistry.has_floor(&"floor_07"), "there is no floor_07")


func _check_round_trip() -> void:
	print("-- Writing and reading a checkpoint")
	var saves := save_manager()
	check(not saves.has_save_file() and saves.load_checkpoint() == null, "at first there is no save")
	check(saves.save_checkpoint(_floor_2_checkpoint()), "a Floor 2 checkpoint is saved")
	check(FileAccess.file_exists(saves.save_path) and not FileAccess.file_exists(saves.save_path + ".tmp"),
			"the save file exists and no temporary file is left")
	var text := FileAccess.get_file_as_string(saves.save_path)
	var data: Variant = JSON.parse_string(text)
	check(data is Dictionary and data["save_version"] == 3, "the file is JSON with save_version 3")
	check(data["floor_id"] == "floor_02" and data["carl"]["health"] == 90 and data["carl"]["max_health"] == 100,
			"it stores the floor id and Carl's HP")
	check(data["donut"] == {"health": 45.0, "max_health": 60.0}, "it stores Donut's HP", str(data.get("donut")))
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
		check(loaded.donut_health == 45 and loaded.donut_max_health == 60, "Donut's HP comes back",
				"%d / %d" % [loaded.donut_health, loaded.donut_max_health])
		check(_quantity(loaded, POTION) == 1, "the potion quantity comes back")
		check(loaded.action_slots == {ActionSlots.SLOT_A: POTION, ActionSlots.SLOT_D: FISTS}, "the slot layout comes back",
				str(loaded.action_slots))

	print("-- A Floor 3 checkpoint with the Slingshot")
	check(saves.save_checkpoint(_floor_3_checkpoint()), "a Floor 3 checkpoint is saved")
	data = JSON.parse_string(FileAccess.get_file_as_string(saves.save_path))
	check(data["save_version"] == 3 and data["floor_id"] == "floor_03" and data["carl"]["health"] == 80,
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

	print("-- Floor 4 and Floor 5 checkpoints, and Donut's HP (Phase 8: save_version 3)")
	check(saves.SAVE_VERSION == 3, "the game writes save_version 3: Donut's HP is a new kind of saved data")
	var floor_3_data: Dictionary = saves.encode(_floor_3_checkpoint())
	check(floor_3_data.keys() == ["save_version", "floor_id", "carl", "donut", "inventory", "owned_items", "action_slots"],
			"a checkpoint has exactly the fields save_version, floor_id, carl, donut, inventory, owned_items, action_slots",
			str(floor_3_data.keys()))
	for floor_path: String in [FLOOR_4_PATH, FLOOR_5_PATH]:
		var checkpoint := _floor_3_checkpoint()
		checkpoint.scene_path = floor_path
		checkpoint.donut_health = 40
		var floor_data: Dictionary = saves.encode(checkpoint)
		var floor_id := FloorRegistry.get_floor_id(floor_path)
		check(floor_data.keys() == floor_3_data.keys() and floor_data["floor_id"] == String(floor_id) and floor_data["save_version"] == 3
				and floor_data["donut"] == {"health": 40, "max_health": 60},
				"a %s checkpoint has the same fields, with floor_id %s and Donut at 40 / 60" % [FloorRegistry.get_display_name(floor_id), floor_id])
		check(saves.save_checkpoint(checkpoint), "the %s checkpoint is saved" % FloorRegistry.get_display_name(floor_id))
		loaded = saves.load_checkpoint()
		check(loaded != null and loaded.scene_path == floor_path and loaded.carl_health == 80 and loaded.donut_health == 40
				and loaded.donut_max_health == 60
				and loaded.action_slots == {ActionSlots.SLOT_W: SLINGSHOT, ActionSlots.SLOT_A: POTION, ActionSlots.SLOT_D: FISTS},
				"it loads back as %s with Carl's and Donut's HP and the slots" % FloorRegistry.get_display_name(floor_id), saves.last_error)
	var downed := _floor_3_checkpoint()
	downed.scene_path = FLOOR_5_PATH
	downed.donut_health = 0
	saves.save_checkpoint(downed)
	data = JSON.parse_string(FileAccess.get_file_as_string(saves.save_path))
	loaded = saves.load_checkpoint()
	check(data["donut"]["health"] == 0 and loaded != null and loaded.donut_health == 0 and loaded.donut_max_health == 60,
			"Donut entering a floor downed is saved and loaded as 0 / 60", saves.last_error)

	print("-- A Floor 6 checkpoint with the Baseball Bat (Phase 9: still save_version 3)")
	var floor_6 := _floor_6_checkpoint()
	var floor_6_data: Dictionary = saves.encode(floor_6)
	check(floor_6_data.keys() == floor_3_data.keys() and floor_6_data["save_version"] == 3 and floor_6_data["floor_id"] == "floor_06",
			"a Floor 6 checkpoint has exactly the same fields and save_version 3: owning the Bat is no new kind of saved data",
			str(floor_6_data.keys()))
	check(floor_6_data["owned_items"] == ["slingshot", "baseball_bat"] and floor_6_data["inventory"] == {"small_health_potion": 1},
			"the Bat is stored as one more owned item id, with no quantity", "%s / %s" % [floor_6_data["owned_items"], floor_6_data["inventory"]])
	check(floor_6_data["action_slots"] == {"action_w": "slingshot", "action_a": "small_health_potion", "action_s": "baseball_bat", "action_d": "fists"},
			"S = baseball_bat is stored", str(floor_6_data["action_slots"]))
	check(saves.save_checkpoint(floor_6), "the Floor 6 checkpoint is saved")
	data = JSON.parse_string(FileAccess.get_file_as_string(saves.save_path))
	check(data["save_version"] == 3, "the file says save_version 3")
	loaded = saves.load_checkpoint()
	check(loaded != null and loaded.scene_path == FLOOR_6_PATH and loaded.carl_health == 80 and loaded.donut_health == 30,
			"it loads back as Floor 6 with Carl 80 and Donut 30", saves.last_error)
	if loaded != null:
		var inventory := Inventory.new()
		inventory.restore_snapshot(loaded.inventory)
		check(inventory.has(BAT) and inventory.has(SLINGSHOT) and inventory.get_quantity(BAT) == 0 and inventory.get_quantity(POTION) == 1,
				"the loaded inventory owns the Bat (no quantity) and the Slingshot, and has 1 potion")
		check(loaded.action_slots == {ActionSlots.SLOT_W: SLINGSHOT, ActionSlots.SLOT_A: POTION, ActionSlots.SLOT_S: BAT, ActionSlots.SLOT_D: FISTS},
				"the loaded layout has W = Slingshot, A = potion, S = Baseball Bat, D = Fists", str(loaded.action_slots))

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
		"unsupported save_version 4": func(d: Dictionary) -> void: d["save_version"] = 4,
		"unsupported save_version 999": func(d: Dictionary) -> void: d["save_version"] = 999,
		"save_version 0": func(d: Dictionary) -> void: d["save_version"] = 0,
		"save_version as a string": func(d: Dictionary) -> void: d["save_version"] = "1",
		"no save_version": func(d: Dictionary) -> void: d.erase("save_version"),
		"no floor_id": func(d: Dictionary) -> void: d.erase("floor_id"),
		"an unknown floor": func(d: Dictionary) -> void: d["floor_id"] = "floor_99",
		"floor_07, which does not exist": func(d: Dictionary) -> void: d["floor_id"] = "floor_07",
		"a scene path instead of a floor id": func(d: Dictionary) -> void: d["floor_id"] = FLOOR_2_PATH,
		"no carl": func(d: Dictionary) -> void: d.erase("carl"),
		"HP as a string": func(d: Dictionary) -> void: d["carl"]["health"] = "90",
		"HP 0": func(d: Dictionary) -> void: d["carl"]["health"] = 0,
		"HP above max": func(d: Dictionary) -> void: d["carl"]["health"] = 101,
		"fractional HP": func(d: Dictionary) -> void: d["carl"]["health"] = 90.5,
		"max HP 0": func(d: Dictionary) -> void: d["carl"]["max_health"] = 0,
		"no donut": func(d: Dictionary) -> void: d.erase("donut"),
		"donut as null": func(d: Dictionary) -> void: d["donut"] = null,
		"donut as a number": func(d: Dictionary) -> void: d["donut"] = 60,
		"donut as a list": func(d: Dictionary) -> void: d["donut"] = [45, 60],
		"no donut health": func(d: Dictionary) -> void: d["donut"].erase("health"),
		"no donut max_health": func(d: Dictionary) -> void: d["donut"].erase("max_health"),
		"Donut HP as a string": func(d: Dictionary) -> void: d["donut"]["health"] = "45",
		"negative Donut HP": func(d: Dictionary) -> void: d["donut"]["health"] = -1,
		"Donut HP above her maximum": func(d: Dictionary) -> void: d["donut"]["health"] = 61,
		"fractional Donut HP": func(d: Dictionary) -> void: d["donut"]["health"] = 44.5,
		"Donut HP as null": func(d: Dictionary) -> void: d["donut"]["health"] = null,
		"Donut max HP 0": func(d: Dictionary) -> void: d["donut"]["max_health"] = 0,
		"Donut max HP above the limit": func(d: Dictionary) -> void: d["donut"]["max_health"] = 5000,
		"Donut max HP as a string": func(d: Dictionary) -> void: d["donut"]["max_health"] = "60",
		"no inventory": func(d: Dictionary) -> void: d.erase("inventory"),
		"inventory as a list": func(d: Dictionary) -> void: d["inventory"] = [],
		"a negative quantity": func(d: Dictionary) -> void: d["inventory"]["small_health_potion"] = -1,
		"a fractional quantity": func(d: Dictionary) -> void: d["inventory"]["small_health_potion"] = 1.5,
		"a quantity as a string": func(d: Dictionary) -> void: d["inventory"]["small_health_potion"] = "2",
		"an unknown item": func(d: Dictionary) -> void: d["inventory"]["mystery_item"] = 1,
		"innate Fists carried as an item": func(d: Dictionary) -> void: d["inventory"]["fists"] = 1,
		"the reusable Slingshot with a quantity": func(d: Dictionary) -> void: d["inventory"]["slingshot"] = 1,
		"the reusable Baseball Bat with a quantity": func(d: Dictionary) -> void: d["inventory"]["baseball_bat"] = 1,
		"no owned_items": func(d: Dictionary) -> void: d.erase("owned_items"),
		"owned_items as an object": func(d: Dictionary) -> void: d["owned_items"] = {"slingshot": 1},
		"owned_items as a string": func(d: Dictionary) -> void: d["owned_items"] = "slingshot",
		"an unknown owned item": func(d: Dictionary) -> void: d["owned_items"] = ["laser_sword"],
		"a scene path as an owned item": func(d: Dictionary) -> void: d["owned_items"] = ["res://scenes/actions/slingshot.tscn"],
		"an owned item that is a number": func(d: Dictionary) -> void: d["owned_items"] = [5],
		"a consumable in owned_items": func(d: Dictionary) -> void: d["owned_items"] = ["small_health_potion"],
		"innate Fists in owned_items": func(d: Dictionary) -> void: d["owned_items"] = ["fists"],
		"an owned item listed twice": func(d: Dictionary) -> void: d["owned_items"] = ["slingshot", "slingshot"],
		"the Baseball Bat listed twice": func(d: Dictionary) -> void: d["owned_items"] = ["baseball_bat", "slingshot", "baseball_bat"],
		"an unknown owned item next to the Bat": func(d: Dictionary) -> void: d["owned_items"] = ["baseball_bat", "golden_bat"],
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
	data["action_slots"]["action_s"] = "baseball_bat"
	loaded = _load_data(data)
	check(loaded != null and not loaded.action_slots.has(ActionSlots.SLOT_S) and loaded.action_slots.get(ActionSlots.SLOT_A) == POTION,
			"a Baseball Bat slot without owning the Bat is emptied, the rest is kept")
	data["owned_items"] = ["baseball_bat"]
	loaded = _load_data(data)
	check(loaded != null and loaded.action_slots.get(ActionSlots.SLOT_S) == BAT, "with the Bat owned, S = Baseball Bat is kept")
	data = _valid_data()
	data["carl"]["health"] = 90.0
	data["donut"]["health"] = 45.0
	check(_load_data(data) != null, "whole numbers written as 90.0 are accepted")
	data = _valid_data()
	data["donut"]["health"] = 0
	loaded = _load_data(data)
	check(loaded != null and loaded.donut_health == 0, "Donut at 0 HP is valid: she entered the floor downed")
	data = _valid_data()
	data["donut"]["health"] = 60
	loaded = _load_data(data)
	check(loaded != null and loaded.donut_health == 60, "Donut at exactly her maximum is valid")


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


## A Floor 2 checkpoint: Carl 90/100 HP, Donut 45/60 HP, 1 potion on A, Fists on D.
func _floor_2_checkpoint() -> FloorEntry:
	var inventory := Inventory.new()
	inventory.reset([FISTS])
	inventory.add(POTION, 1)
	var checkpoint := FloorEntry.new()
	checkpoint.scene_path = FLOOR_2_PATH
	checkpoint.carl_health = 90
	checkpoint.carl_max_health = 100
	checkpoint.donut_health = 45
	checkpoint.donut_max_health = 60
	checkpoint.inventory = inventory.get_snapshot()
	checkpoint.action_slots = {ActionSlots.SLOT_A: POTION, ActionSlots.SLOT_D: FISTS}
	return checkpoint


## A Floor 3 checkpoint: Carl 80/100 HP, Donut 60/60 HP, 1 potion on A, the Slingshot owned
## and on W, Fists on D.
func _floor_3_checkpoint() -> FloorEntry:
	var inventory := Inventory.new()
	inventory.reset([FISTS])
	inventory.add(POTION, 1)
	inventory.add(SLINGSHOT, 1)
	var checkpoint := FloorEntry.new()
	checkpoint.scene_path = FLOOR_3_PATH
	checkpoint.carl_health = 80
	checkpoint.carl_max_health = 100
	checkpoint.donut_health = 60
	checkpoint.donut_max_health = 60
	checkpoint.inventory = inventory.get_snapshot()
	checkpoint.action_slots = {ActionSlots.SLOT_W: SLINGSHOT, ActionSlots.SLOT_A: POTION, ActionSlots.SLOT_D: FISTS}
	return checkpoint


## A Floor 6 checkpoint (Phase 9): Carl 80/100 HP, Donut 30/60 HP, 1 potion on A, the Slingshot
## on W, the Baseball Bat on S, Fists on D.
func _floor_6_checkpoint() -> FloorEntry:
	var checkpoint := _floor_3_checkpoint()
	var inventory := Inventory.new()
	inventory.restore_snapshot(checkpoint.inventory)
	inventory.add(BAT, 1)
	checkpoint.scene_path = FLOOR_6_PATH
	checkpoint.donut_health = 30
	checkpoint.inventory = inventory.get_snapshot()
	checkpoint.action_slots[ActionSlots.SLOT_S] = BAT
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
