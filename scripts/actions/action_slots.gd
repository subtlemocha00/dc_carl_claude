class_name ActionSlots
extends RefCounted
## Which action each of Carl's four action slots holds.
## A slot is named after its InputMap action (action_w, action_a, action_s, action_d): pressing the
## key bound to that action uses whatever the slot holds. The slots are logical: "the W slot" is
## action_w, whichever physical key triggers it (W by default; the player can rebind it in
## Settings, Phase 13). What a slot holds is run state (GameState, the save); which key triggers it
## is an application setting (SettingsManager). Changing the key never changes the contents.
## GameState owns the current run's ActionSlots. Carl, the HUD and the action menu all share
## it, so a change made in the menu applies everywhere at once and survives level changes.
## Rules:
## - An action sits in at most one slot: putting it in a slot takes it out of its old one.
## - Only actions in Carl's inventory can be put in a slot.
## - A slot empties by itself when its action leaves the inventory, for example when the
##   last potion is used or a floor retry takes back an item. A slot never holds something
##   Carl does not have.

## Emitted after any slot's contents change.
signal changed

const SLOT_W := &"action_w"
const SLOT_A := &"action_a"
const SLOT_S := &"action_s"
const SLOT_D := &"action_d"
## Every slot, in display order.
const SLOTS: Array[StringName] = [SLOT_W, SLOT_A, SLOT_S, SLOT_D]
## The logical name of each slot ("Action Slot W" in Settings). The key that triggers a slot is
## shown with ControlBindings.get_key_label(slot) instead, since it may have been rebound.
const SLOT_NAMES: Dictionary[StringName, String] = {SLOT_W: "W", SLOT_A: "A", SLOT_S: "S", SLOT_D: "D"}
## Shown in place of an action name for an empty slot.
const EMPTY_LABEL := "—"

## Carl's inventory: the actions the slots may hold.
var inventory: Inventory

var _actions: Dictionary[StringName, ActionDefinition] = {}


func _init(carl_inventory: Inventory) -> void:
	inventory = carl_inventory
	inventory.changed.connect(_empty_slots_of_missing_actions)


## The action in `slot`, or null if the slot is empty.
func get_action(slot: StringName) -> ActionDefinition:
	return _actions.get(slot)


## What `slot` holds, as shown to the player: the action's name with its quantity for a
## carried item (see Inventory.get_label()), or EMPTY_LABEL. `short` uses the short name.
func get_display_name(slot: StringName, short: bool = false) -> String:
	var action := get_action(slot)
	return inventory.get_label(action, short) if action != null else EMPTY_LABEL


## The slot holding `action`, or &"" if no slot holds it.
func find_slot(action: ActionDefinition) -> StringName:
	for slot in SLOTS:
		var held := get_action(slot)
		if held != null and held.id == action.id:
			return slot
	return &""


## Puts `action` in `slot` and empties the slot it was in before. An action that was already
## in `slot` is simply replaced; Carl still has it, it just has no key until assigned again.
## Returns false, changing nothing, if the action cannot be put in a slot or Carl does not
## have it.
func assign(action: ActionDefinition, slot: StringName) -> bool:
	if slot not in SLOTS:
		push_error("'%s' is not an action slot." % slot)
		return false
	if not action.assignable or not inventory.has(action):
		return false
	var previous_slot := find_slot(action)
	if previous_slot == slot:
		return true
	if previous_slot != &"":
		_actions.erase(previous_slot)
	_actions[slot] = action
	changed.emit()
	return true


## Empties every slot.
func clear_all() -> void:
	_actions.clear()
	changed.emit()


## The action in each slot (slot name -> action). Empty slots are left out. A floor checkpoint
## keeps a copy.
func get_layout() -> Dictionary[StringName, ActionDefinition]:
	return _actions.duplicate()


## Puts each action of `layout` back in its slot, but only where the slot is empty now and the
## action is in no other slot, so choices made since the layout was taken are kept. As always,
## only actions Carl has are accepted. A retry uses this to give a slot back its item after
## the item ran out and returned, and Continue uses it on emptied slots to restore a whole
## saved layout.
func fill_empty_slots(layout: Dictionary[StringName, ActionDefinition]) -> void:
	for slot in SLOTS:
		var action: ActionDefinition = layout.get(slot)
		if action != null and get_action(slot) == null and find_slot(action) == &"":
			assign(action, slot)


func _empty_slots_of_missing_actions() -> void:
	var emptied := false
	for slot in SLOTS:
		var action := get_action(slot)
		if action != null and not inventory.has(action):
			_actions.erase(slot)
			emptied = true
	if emptied:
		changed.emit()
