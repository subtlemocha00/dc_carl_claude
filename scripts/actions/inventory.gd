class_name Inventory
extends RefCounted
## Everything Carl has during the current run, and how many of each item.
## - Innate actions (Fists) are always there. They have no quantity and are never used up.
## - Carried items (Small Health Potion) are counted. An item leaves the inventory when its
##   quantity drops to 0, and comes back when Carl picks up more.
## GameState owns the run's single Inventory, so each quantity is stored in exactly one place:
## - pickups add to it (through Carl);
## - using a consumable removes from it;
## - a floor retry restores a snapshot of it;
## - the HUD and the action menu only read it.

## Emitted after anything in the inventory changes.
signal changed

var _innate: Array[ActionDefinition] = []
## Carried items by id, in the order Carl got them.
var _items: Dictionary[StringName, ActionDefinition] = {}
var _quantities: Dictionary[StringName, int] = {}


## Empties the inventory and gives Carl `innate_actions`, which he keeps for the whole run.
func reset(innate_actions: Array[ActionDefinition]) -> void:
	_innate = innate_actions.duplicate()
	_items.clear()
	_quantities.clear()
	changed.emit()


## Every action Carl has: innate actions first, then carried items in the order he got them.
func get_actions() -> Array[ActionDefinition]:
	var actions := _innate.duplicate()
	actions.append_array(_items.values())
	return actions


## True if Carl has `action`: it is innate, or he carries at least one.
func has(action: ActionDefinition) -> bool:
	return is_innate(action) or get_quantity(action) > 0


func is_innate(action: ActionDefinition) -> bool:
	return _innate.any(func(innate: ActionDefinition) -> bool: return innate.id == action.id)


## How many of a carried item Carl has. 0 if he has none, and for innate actions.
func get_quantity(action: ActionDefinition) -> int:
	return _quantities.get(action.id, 0)


## Gives Carl `amount` more of a carried item.
func add(item: ActionDefinition, amount: int) -> void:
	if amount <= 0:
		return
	if is_innate(item):
		push_error("'%s' is innate, so it cannot also be carried." % item.id)
		return
	if not _items.has(item.id):
		_items[item.id] = item
		_quantities[item.id] = 0
	_quantities[item.id] += amount
	changed.emit()


## Takes `amount` of a carried item away. Returns false, taking nothing, if Carl has fewer.
func remove(item: ActionDefinition, amount: int) -> bool:
	if amount <= 0 or get_quantity(item) < amount:
		return false
	_quantities[item.id] -= amount
	if _quantities[item.id] == 0:
		_items.erase(item.id)
		_quantities.erase(item.id)
	changed.emit()
	return true


## The action's name for the HUD and menus, with " xN" after a carried item.
## With `short` true it uses the action's short name.
func get_label(action: ActionDefinition, short: bool = false) -> String:
	var action_name := action.get_short_name() if short else action.display_name
	if is_innate(action):
		return action_name
	return "%s x%d" % [action_name, get_quantity(action)]


## A copy of the carried items, to give back to restore_snapshot() later. The floor-entry
## state keeps one. Innate actions never change during a run, so they are not included.
func get_snapshot() -> Dictionary:
	return {"items": _items.duplicate(), "quantities": _quantities.duplicate()}


## Puts the carried items back exactly as they were when `snapshot` was taken.
func restore_snapshot(snapshot: Dictionary) -> void:
	_items = snapshot["items"].duplicate()
	_quantities = snapshot["quantities"].duplicate()
	changed.emit()
