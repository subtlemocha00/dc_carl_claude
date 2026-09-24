class_name Inventory
extends RefCounted
## Everything Carl has during the current run. It holds three kinds of things:
## - Innate actions (Fists) are always there. They are never found, have no quantity and are
##   never used up.
## - Reusable items (Slingshot: ActionDefinition.consumable is false) are found once and then
##   owned. They have no quantity and are never used up; finding one again changes nothing.
## - Consumables (Small Health Potion: consumable is true) are counted. A consumable leaves the
##   inventory when its quantity drops to 0, and comes back when Carl picks up more.
## Reusable items and consumables are both "carried items": found in levels, and taken back
## by a floor retry. Only consumables have a quantity.
## GameState owns the run's single Inventory, so each item is stored in exactly one place:
## - pickups add to it (through Carl);
## - using a consumable removes from it;
## - a floor retry restores a snapshot of it;
## - the HUD and the action menu only read it.

## Emitted after anything in the inventory changes.
signal changed

var _innate: Array[ActionDefinition] = []
## Carried items (reusable items and consumables) by id, in the order Carl got them.
var _items: Dictionary[StringName, ActionDefinition] = {}
## How many of each consumable Carl carries. Reusable items are owned, not counted, so they
## are never in here.
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


## True if Carl has `action`: it is innate, he owns it (a reusable item), or he carries at
## least one (a consumable).
func has(action: ActionDefinition) -> bool:
	if is_innate(action):
		return true
	if action.consumable:
		return get_quantity(action) > 0
	return _items.has(action.id)


func is_innate(action: ActionDefinition) -> bool:
	return _innate.any(func(innate: ActionDefinition) -> bool: return innate.id == action.id)


## How many of a consumable Carl has. 0 if he has none, and always 0 for innate actions and
## reusable items, which are not counted.
func get_quantity(action: ActionDefinition) -> int:
	return _quantities.get(action.id, 0)


## Gives Carl an item he found: `amount` more of a consumable, or a reusable item to own (for
## a reusable item `amount` only has to be positive). Finding a reusable item he already owns
## changes nothing, so he can never own two.
func add(item: ActionDefinition, amount: int) -> void:
	if amount <= 0:
		return
	if is_innate(item):
		push_error("'%s' is innate, so it cannot also be carried." % item.id)
		return
	if not item.consumable:
		if _items.has(item.id):
			return
		_items[item.id] = item
		changed.emit()
		return
	if not _items.has(item.id):
		_items[item.id] = item
		_quantities[item.id] = 0
	_quantities[item.id] += amount
	changed.emit()


## Takes `amount` of a consumable away. Returns false, taking nothing, if Carl has fewer.
## Reusable items have no quantity, so they can never be removed this way: they are never
## used up.
func remove(item: ActionDefinition, amount: int) -> bool:
	if amount <= 0 or get_quantity(item) < amount:
		return false
	_quantities[item.id] -= amount
	if _quantities[item.id] == 0:
		_items.erase(item.id)
		_quantities.erase(item.id)
	changed.emit()
	return true


## The action's name for the HUD and menus: " xN" after a consumable, the plain name for
## anything reusable (see ActionDefinition.get_label()). With `short` true it uses the
## action's short name.
func get_label(action: ActionDefinition, short: bool = false) -> String:
	return action.get_label(get_quantity(action), short)


## A copy of the carried items (reusable items and consumable quantities), to give back to
## restore_snapshot() later. The floor-entry state keeps one. Innate actions never change
## during a run, so they are not included.
func get_snapshot() -> Dictionary:
	return {"items": _items.duplicate(), "quantities": _quantities.duplicate()}


## Puts the carried items back exactly as they were when `snapshot` was taken.
func restore_snapshot(snapshot: Dictionary) -> void:
	_items = snapshot["items"].duplicate()
	_quantities = snapshot["quantities"].duplicate()
	changed.emit()
