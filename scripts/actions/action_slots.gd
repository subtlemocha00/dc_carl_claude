class_name ActionSlots
extends RefCounted
## Which action each of Carl's four action slots holds.
## A slot is named after the InputMap action of its key (action_w, action_a, action_s,
## action_d): pressing that key uses whatever the slot holds.
## GameState owns the current run's ActionSlots. Carl, the HUD and the action menu all share
## it, so a change made in the menu applies everywhere at once and survives level changes.
## An action sits in at most one slot: putting it in a slot takes it out of its old one.

## Emitted after any slot's contents change.
signal changed

const SLOT_W := &"action_w"
const SLOT_A := &"action_a"
const SLOT_S := &"action_s"
const SLOT_D := &"action_d"
## Every slot, in display order.
const SLOTS: Array[StringName] = [SLOT_W, SLOT_A, SLOT_S, SLOT_D]
## The key shown for each slot.
const KEY_LABELS: Dictionary[StringName, String] = {SLOT_W: "W", SLOT_A: "A", SLOT_S: "S", SLOT_D: "D"}
## Shown in place of an action name for an empty slot.
const EMPTY_LABEL := "—"

var _actions: Dictionary[StringName, ActionDefinition] = {}


## The action in `slot`, or null if the slot is empty.
func get_action(slot: StringName) -> ActionDefinition:
	return _actions.get(slot)


## The name of the action in `slot`, or EMPTY_LABEL if the slot is empty.
func get_display_name(slot: StringName) -> String:
	var action := get_action(slot)
	return action.display_name if action != null else EMPTY_LABEL


## The slot holding `action`, or &"" if no slot holds it.
func find_slot(action: ActionDefinition) -> StringName:
	for slot in SLOTS:
		var held := get_action(slot)
		if held != null and held.id == action.id:
			return slot
	return &""


## Puts `action` in `slot` and empties the slot it was in before. An action that was already
## in `slot` is simply replaced; Carl still has it, it just has no key until assigned again.
## Returns false, changing nothing, if the action cannot be put in a slot.
func assign(action: ActionDefinition, slot: StringName) -> bool:
	if slot not in SLOTS:
		push_error("'%s' is not an action slot." % slot)
		return false
	if not action.assignable:
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
