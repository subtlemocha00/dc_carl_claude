extends Node
## Autoloaded as SaveManager. Reads and writes the game's one save: the checkpoint (FloorEntry)
## of the floor Carl last entered. GameState keeps the run in memory; this is the only script
## that touches the save file.
##
## The file is JSON with stable ids only, never scene paths or resources:
##     {"save_version": 1, "floor_id": "floor_02",
##      "carl": {"health": 90, "max_health": 100},
##      "inventory": {"small_health_potion": 1},
##      "action_slots": {"action_w": null, "action_a": "small_health_potion",
##                       "action_s": null, "action_d": "fists"}}
##
## A save file is untrusted input. Loading it:
## - rejects the whole file (the title screen then offers no Continue) if it is not valid JSON,
##   has a different save_version, an unknown floor, HP that is not a whole number in range,
##   an unknown or innate item, a quantity that is not a whole number from 0 to MAX_QUANTITY,
##   or slots that are not exactly the four slot names with an id or null each;
## - empties a slot, but keeps the rest of the save, if the slot names an unknown action or
##   an action Carl would not have. The same rules as in the game decide that
##   (ActionSlots.assign()).
## A rejected file is never changed, and loading reports why in `last_error` instead of logging
## an engine error.

## The format written by this version. A future format bumps this, and decode() is where
## older files would be migrated before being read.
const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://savegame.json"
const MAX_HEALTH_LIMIT := 1000
const MAX_QUANTITY := 999

## Where the save lives. Tests point this at their own file so a player's save is never touched.
var save_path: String = DEFAULT_SAVE_PATH
## Why the last load_checkpoint() returned null ("" after a successful load).
var last_error: String = ""


## True if a save file exists, loadable or not.
func has_save_file() -> bool:
	return not _find_file_to_load().is_empty()


## Writes `checkpoint` as the save, replacing the previous one only once the new file is
## complete. Returns false (the old save stays as it was) if it could not be written.
func save_checkpoint(checkpoint: FloorEntry) -> bool:
	var data := encode(checkpoint)
	if data.is_empty():
		return false
	var text := JSON.stringify(data, "\t")
	# Write a temporary file, check it, then rename it over the old save. If the game stops
	# part-way, the old save is still intact.
	var temp_path := _get_temp_path()
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write the save file %s: %s." % [temp_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(text)
	var write_error := file.get_error()
	file.close()
	if write_error != OK or FileAccess.get_file_as_string(temp_path) != text:
		push_error("Could not write the save file %s." % temp_path)
		return false
	var rename_error := DirAccess.rename_absolute(temp_path, save_path)
	if rename_error != OK:
		push_error("Could not replace the save file %s: %s." % [save_path, error_string(rename_error)])
		return false
	return true


## Reads and checks the save. Returns the checkpoint, or null (with the reason in last_error)
## if there is no save or it cannot be trusted.
func load_checkpoint() -> FloorEntry:
	var path := _find_file_to_load()
	if path.is_empty():
		return _reject("there is no save file")
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return _reject("the save file is empty or unreadable")
	var json := JSON.new()
	if json.parse(text) != OK:
		return _reject("the save file is not valid JSON (line %d: %s)" % [json.get_error_line(), json.get_error_message()])
	return decode(json.data)


## Deletes the save (and any unfinished temporary file). Does nothing if there is none.
func delete_save() -> void:
	for path in [save_path, _get_temp_path()]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## The save data for `checkpoint`, or {} if its level is not a registered floor.
func encode(checkpoint: FloorEntry) -> Dictionary:
	var floor_id := FloorRegistry.get_floor_id(checkpoint.scene_path)
	if floor_id == &"":
		push_error("'%s' is not in FloorRegistry, so it cannot be saved." % checkpoint.scene_path)
		return {}
	var inventory := Inventory.new()
	inventory.restore_snapshot(checkpoint.inventory)
	var quantities := {}
	for item in inventory.get_actions():
		quantities[String(item.id)] = inventory.get_quantity(item)
	var slots := {}
	for slot in ActionSlots.SLOTS:
		var action: ActionDefinition = checkpoint.action_slots.get(slot)
		slots[String(slot)] = null
		if action != null:
			slots[String(slot)] = String(action.id)
	return {
		"save_version": SAVE_VERSION,
		"floor_id": String(floor_id),
		"carl": {"health": checkpoint.carl_health, "max_health": checkpoint.carl_max_health},
		"inventory": quantities,
		"action_slots": slots,
	}


## Turns save data back into a checkpoint, or returns null (reason in last_error).
func decode(data: Variant) -> FloorEntry:
	if not data is Dictionary:
		return _reject("the save data is not a JSON object")
	var version: Variant = data.get("save_version")
	if not _is_whole_number(version):
		return _reject("save_version is missing or not a whole number")
	if int(version) != SAVE_VERSION:
		# Older formats would be migrated to the current one here, before reading them.
		return _reject("save_version %d is not supported (this game reads version %d)" % [int(version), SAVE_VERSION])
	return _decode_current_version(data)


func _decode_current_version(data: Dictionary) -> FloorEntry:
	var floor_id: Variant = data.get("floor_id")
	if not floor_id is String or not FloorRegistry.has_floor(floor_id):
		return _reject("floor_id %s is not a known floor" % JSON.stringify(floor_id))

	var carl: Variant = data.get("carl")
	if not carl is Dictionary:
		return _reject("carl is missing")
	var max_health: Variant = carl.get("max_health")
	var health: Variant = carl.get("health")
	if not _is_whole_number(max_health) or int(max_health) < 1 or int(max_health) > MAX_HEALTH_LIMIT:
		return _reject("carl.max_health %s is not a whole number from 1 to %d" % [JSON.stringify(max_health), MAX_HEALTH_LIMIT])
	if not _is_whole_number(health) or int(health) < 1 or int(health) > int(max_health):
		return _reject("carl.health %s is not a whole number from 1 to max_health" % JSON.stringify(health))

	# Rebuild the inventory through the real Inventory, so the checkpoint holds exactly what
	# the game itself would have recorded.
	var saved_items: Variant = data.get("inventory")
	if not saved_items is Dictionary:
		return _reject("inventory is missing")
	var inventory := Inventory.new()
	inventory.reset(GameState.INNATE_ACTIONS)
	for item_id: Variant in saved_items:
		var item: ActionDefinition = ActionRegistry.find(item_id) if item_id is String else null
		if item == null:
			return _reject("inventory item %s is unknown" % JSON.stringify(item_id))
		if inventory.is_innate(item):
			return _reject("inventory item '%s' is innate and cannot be carried" % item_id)
		var quantity: Variant = saved_items[item_id]
		if not _is_whole_number(quantity) or int(quantity) < 0 or int(quantity) > MAX_QUANTITY:
			return _reject("the quantity of '%s' is %s, not a whole number from 0 to %d" % [item_id, JSON.stringify(quantity), MAX_QUANTITY])
		inventory.add(item, int(quantity))

	# Slots must be exactly the four slot names. Each holds an action id or null.
	var saved_slots: Variant = data.get("action_slots")
	if not saved_slots is Dictionary or saved_slots.size() != ActionSlots.SLOTS.size():
		return _reject("action_slots must list exactly the slots %s" % [ActionSlots.SLOTS])
	var layout: Dictionary[StringName, ActionDefinition] = {}
	for slot in ActionSlots.SLOTS:
		if not saved_slots.has(String(slot)):
			return _reject("action_slots has no '%s'" % slot)
		var action_id: Variant = saved_slots[String(slot)]
		if action_id != null and not action_id is String:
			return _reject("action_slots.%s must be an action id or null" % slot)
		var action: ActionDefinition = ActionRegistry.find(action_id) if action_id != null else null
		if action != null:
			layout[slot] = action
	# Unknown actions were already dropped above. Filling fresh slots from the layout with the
	# game's own rules drops actions Carl would not have (for example a potion with quantity 0)
	# and keeps an action in only one slot.
	var slots := ActionSlots.new(inventory)
	slots.fill_empty_slots(layout)

	var checkpoint := FloorEntry.new()
	checkpoint.scene_path = FloorRegistry.get_scene_path(floor_id)
	checkpoint.carl_health = int(health)
	checkpoint.carl_max_health = int(max_health)
	checkpoint.inventory = inventory.get_snapshot()
	checkpoint.action_slots = slots.get_layout()
	last_error = ""
	return checkpoint


## The file load_checkpoint() reads: the save, or else a finished temporary file left behind
## if the game stopped between writing it and renaming it. "" if there is neither.
func _find_file_to_load() -> String:
	for path in [save_path, _get_temp_path()]:
		if FileAccess.file_exists(path):
			return path
	return ""


func _get_temp_path() -> String:
	return save_path + ".tmp"


func _reject(reason: String) -> FloorEntry:
	last_error = reason
	return null


## JSON numbers are read as floats, so a whole number is an int or a float without a fraction.
func _is_whole_number(value: Variant) -> bool:
	if value is int:
		return true
	return value is float and is_finite(value) and value == floorf(value)
